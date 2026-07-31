#define TINY_GSM_MODEM_SIM7600 // Cambia a A7672X si tu placa usa ese chip específico

#include <Arduino.h>
#include <TinyGsmClient.h>
#include <ArduinoHttpClient.h> // Librería oficial para HTTP rápido

// --- PUERTOS SERIE DE HARDWARE ---
#define SerialAT     Serial1 // Comunicación con el módem SIM7600
#define SensorSerial Serial2 // Comunicación con el sensor DYP-A19

// --- PINES MÓDEM ---
#define MODEM_TX 18
#define MODEM_RX 19

// --- PINES SENSOR DYP-A19 ---
#define SENSOR_RX 16 // ESP32 RX2 <- Sensor TX
#define SENSOR_TX 17 // ESP32 TX2 -> Sensor RX

// --- PIN Y DIVISOR DE TENSIÓN DE BATERÍA/FUENTE ---
#define PIN_FUENTE 34            // GPIO34 (Entrada analógica ADC1)
const float R1 = 20000.0;        // 20 kΩ
const float R2 = 30000.0;        // 30 kΩ
const float FACTOR_DIVISOR = (R1 + R2) / R2; // Equivale a 1.6667
const float VOLTAJE_REFERENCIA = 3.3; 
const int RESOLUCION_ADC = 4095;

// --- CONFIGURACIÓN RED CELULAR (Claro Argentina) ---
const char apn[]  = "igprs.claro.com.ar";
const char user[] = "";
const char pass[] = "";

// --- CONFIGURACIÓN THINGSPEAK ---
const char server[] = "api.thingspeak.com";
const int port      = 80;
String apiKey       = "UC6FXJB6RIPJH2NB";

// --- OBJETOS RED ---
TinyGsm modem(SerialAT);
TinyGsmClient client(modem);
HttpClient http(client, server, port);

// Variables de tiempo y sensor
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 16000; // 16 segundos (Mínimo de ThingSpeak es 15s)
int ultimaDistancia = -1;

// -------------------------------------------------------------
// FUNCIÓN: Leer Sensor Ultrasónico DYP-A19
// -------------------------------------------------------------
int leerDistanciaDYP() {
  while (SensorSerial.available() > 4) {
    SensorSerial.read();
  }

  if (SensorSerial.available() >= 4) {
    uint8_t datos[4];
    if (SensorSerial.peek() == 0xFF) {
      SensorSerial.readBytes(datos, 4);
      uint8_t checksumCalculado = (datos[0] + datos[1] + datos[2]) & 0xFF;

      if (checksumCalculado == datos[3]) {
        return (datos[1] << 8) + datos[2];
      }
    } else {
      SensorSerial.read();
    }
  }
  return -1;
}

// -------------------------------------------------------------
// FUNCIÓN: Leer Voltaje de la Fuente de Alimentación
// -------------------------------------------------------------
float leerVoltajeFuente() {
  long sumaADC = 0;
  int muestras = 20;

  for (int i = 0; i < muestras; i++) {
    sumaADC += analogRead(PIN_FUENTE);
    delay(2);
  }

  float promedioADC = (float)sumaADC / muestras;
  float voltajePin = (promedioADC / RESOLUCION_ADC) * VOLTAJE_REFERENCIA;
  float voltajeFuente = voltajePin * FACTOR_DIVISOR;

  return voltajeFuente;
}

// -------------------------------------------------------------
// SETUP ROBUTO Y CORREGIDO
// -------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(1000);

  // Configurar resolución del ADC a 12 bits
  analogReadResolution(12);

  // 1. Inicializar Sensor
  SensorSerial.begin(9600, SERIAL_8N1, SENSOR_RX, SENSOR_TX);
  Serial.println("\n--- INICIANDO SISTEMA IOT ESP32 ---");
  Serial.println("Sensor DYP-A19 inicializado.");

  // 2. Inicializar Módem SIM7600
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(3000); // Esperar a que el módem tome tensión adecuadamente

  Serial.println("Inicializando comunicación con el módem...");
  
  int intentosModem = 0;
  while (!modem.init() && intentosModem < 5) {
    Serial.println("Reintentando respuesta del módem AT...");
    delay(1000);
    intentosModem++;
  }

  if (intentosModem >= 5) {
    Serial.println("ERROR CRÍTICO: El módem no responde. Revisa RX/TX y corriente.");
    while (1);
  }

  // Desactivar suspensión automática para evitar desconexiones
  modem.sendAT("+CSCLK=0");
  modem.waitResponse();
  http.setTimeout(5000);

  // Verificación previa de señal antes del registro
  Serial.print("Nivel de señal inicial (CSQ): ");
  Serial.println(modem.getSignalQuality());

  Serial.println("Buscando y registrando en red celular (espera hasta 30s)...");
  
  // Intento de registro progresivo sin congelar el sistema
  bool redOk = false;
  for (int i = 0; i < 30; i++) {
    if (modem.isNetworkConnected()) {
      redOk = true;
      break;
    }
    Serial.print(".");
    delay(1000);
  }
  Serial.println();

  if (!redOk) {
    Serial.println("ADVERTENCIA: No enganchó automáticamente. Forzando búsqueda de red...");
    modem.sendAT("+CFUN=1"); // Forzar reinicio de antena
    modem.waitResponse();
    
    if (!modem.waitForNetwork(15000L)) {
      Serial.println("ERROR CRÍTICO: Sin cobertura o falla de alimentación en el pico 4G.");
      Serial.println("Comprueba: 1) Antena LTE firme 2) Saldo en la SIM 3) Capacitor o fuente de 2A.");
      while (1);
    }
  }
  Serial.println("RED REGISTRADA CORRECTAMENTE (RED OK)");

  Serial.println("Conectando APN Claro Argentina...");
  if (!modem.gprsConnect(apn, user, pass)) {
    Serial.println("ERROR: Fallo al conectar GPRS/Datos.");
    while (1);
  }
  Serial.println("INTERNET CONECTADO (APN OK) - Sistema listo para monitorear");
}

// -------------------------------------------------------------
// LOOP PRINCIPAL
// -------------------------------------------------------------
void loop() {
  // --- LECTURA CONSTANTE DEL SENSOR (Tiempo real) ---
  int distLectura = leerDistanciaDYP();
  if (distLectura > 0) {
    ultimaDistancia = distLectura;
    Serial.print("Distancia actual: ");
    Serial.print(ultimaDistancia);
    Serial.println(" mm");
  }

  // --- ENVÍO PERIÓDICO A THINGSPEAK (Cada 16 segundos) ---
  if (millis() - lastSendTime >= sendInterval) {
    lastSendTime = millis();

    if (ultimaDistancia == -1) {
      Serial.println("Sin lectura válida del sensor ultrasónico aún.");
      return;
    }

    // Verificar y reconectar datos móviles si se perdió la sesión
    if (!modem.isGprsConnected()) {
      Serial.println("Reconectando sesión GPRS...");
      modem.gprsConnect(apn, user, pass);
    }

    // 1. Obtener intensidad de señal celular actual
    int signalQuality = modem.getSignalQuality();
    Serial.print("\n[Estado Red 4G - Señal CSQ: ");
    Serial.print(signalQuality);
    Serial.println("/31]");

    // 2. Medir Voltaje Actual de la Fuente
    float voltajeActual = leerVoltajeFuente();
    Serial.print("Voltaje Entrada 5V: ");
    Serial.print(voltajeActual, 2);
    Serial.print(" V  |  Diagnostico: ");

    if (voltajeActual >= 4.50 && voltajeActual <= 5.50) {
      Serial.println("OK (Alimentación estable)");
    } else if (voltajeActual < 4.50 && voltajeActual > 2.00) {
      Serial.println("ALERTA: Caída de tensión por consumo");
    } else {
      Serial.println("DESCONECTADO / SIN CONTACTO");
    }

    // 3. Crear URL HTTP para enviar field1 (Distancia) y field2 (Voltaje)
    String url = "/update?api_key=" + apiKey + 
                 "&field1=" + String(ultimaDistancia) + 
                 "&field2=" + String(voltajeActual, 2);

    Serial.println("Enviando reporte unificado a ThingSpeak...");

    // 4. Petición HTTP GET
    http.get(url);

    int statusCode = http.responseStatusCode();
    String response = http.responseBody();

    if (statusCode == 200 && response != "0") {
      Serial.print("¡Éxito! Datos guardados en ThingSpeak. Registro ID: ");
      Serial.println(response);
    } else {
      Serial.print("Error en el envío HTTP. Código: ");
      Serial.println(statusCode);
    }

    http.stop(); // Liberar socket/puerto de red
  }

  delay(20); // Fluidez para la lectura serial del sensor
}
