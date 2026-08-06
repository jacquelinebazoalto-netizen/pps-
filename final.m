#define TINY_GSM_MODEM_SIM7600

#include <Arduino.h>
#include <HardwareSerial.h>
#include <TinyGsmClient.h>
#include <ArduinoHttpClient.h>

// --- PINES DE HARDWARE ---
#define MODEM_POWER_PIN   21    // Pin GPIO 21: Alimenta/Enciende el módem SIM7600
#define SENSOR_POWER_PIN  5     // Control de VCC para el sensor DYP-A19
#define SENSOR_RX         16    // ESP32 RX2 <- Sensor TX
#define SENSOR_TX         17    // ESP32 TX2 -> Sensor RX

#define MODEM_TX          26    // ESP32 TX1 -> Módem RX
#define MODEM_RX          27    // ESP32 RX1 <- Módem TX
#define PIN_FUENTE        34    // Divisor de tensión ADC1

// --- CONFIGURACIÓN DE TIEMPOS Y UMBRALES ---
#define UMBRAL_DISTANCIA  1400      // Umbral de alerta en mm
#define TIEMPO_LECTURA_MS 30000     // 30s de escaneo inicial antes de Deep Sleep
#define TIME_TO_SLEEP     30        // 30s en Deep Sleep
#define uS_TO_S_FACTOR    1000000ULL 
#define SEND_INTERVAL_MS  16000     // Intervalo de envío a ThingSpeak (16s min)

// --- DIVISOR DE TENSIÓN ---
const float R1 = 20000.0;
const float R2 = 30000.0;
const float FACTOR_DIVISOR = (R1 + R2) / R2; 
const float VOLTAJE_REFERENCIA = 3.3;
const int RESOLUCION_ADC = 4095;

// --- CONFIGURACIÓN RED Y THINGSPEAK ---
const char apn[]  = "igprs.claro.com.ar";
const char user[] = "";
const char pass[] = "";

const char server[] = "api.thingspeak.com";
const int port      = 80;
String apiKey       = "UC6FXJB6RIPJH2NB";

// --- PUERTOS SERIE Y OBJETOS DE RED ---
HardwareSerial SerialAT(1);      // UART1 Módem SIM7600
HardwareSerial SensorSerial(2);  // UART2 Sensor DYP-A19

TinyGsm modem(SerialAT);
TinyGsmClient client(modem);
HttpClient http(client, server, port);

// --- VARIABLES GLOBALES DE ESTADO ---
bool alertaBloqueada = false;
bool modemEncendido = false;
unsigned long tiempoInicioCiclo = 0;
unsigned long ultimoEnvioThingSpeak = 0;
int ultimaDistanciaValida = -1;

// --- PROTOTIPOS DE FUNCIÓN ---
int leerDistanciaDYP();
float leerVoltajeFuente();
bool encenderYConectarModem();
void enviarThingSpeak(int distancia, float voltaje);

// =============================================================
// SETUP
// =============================================================
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println("\n==========================================");
  Serial.println("--- ESP32: Fase 1 (Módem OFF - Muestreo) ---");
  Serial.println("==========================================");

  analogReadResolution(12);

  // 1. Asegurar Módem APAGADO (Pin 21 en LOW)
  pinMode(MODEM_POWER_PIN, OUTPUT);
  digitalWrite(MODEM_POWER_PIN, LOW); 

  // 2. Encender alimentación del sensor (Pin 5 en HIGH)
  pinMode(SENSOR_POWER_PIN, OUTPUT);
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  
  // Inicializar comunicación con el sensor
  SensorSerial.begin(9600, SERIAL_8N1, SENSOR_RX, SENSOR_TX);

  delay(1500); // Estabilización inicial del sensor
  tiempoInicioCiclo = millis();
}

// =============================================================
// LOOP PRINCIPAL
// =============================================================
void loop() {
  // -----------------------------------------------------------
  // PASO 1: Muestreo continuo del sensor ultrasónico
  // -----------------------------------------------------------
  int dist = leerDistanciaDYP();
  if (dist > 0) {
    ultimaDistanciaValida = dist;
    Serial.print("Distancia: ");
    Serial.print(ultimaDistanciaValida);
    Serial.print(" mm");

    // Si supera 1400 mm y el módem no ha sido encendido
    if (ultimaDistanciaValida > UMBRAL_DISTANCIA && !alertaBloqueada) {
      Serial.println("\n\n**************************************************");
      Serial.println("¡ALERTA DETECTADA! Distancia > 1400 mm");
      Serial.println("Encendiendo Módem SIM7600 en PIN 21...");
      Serial.println("**************************************************");
      
      alertaBloqueada = true; // Inhabilita el paso a Deep Sleep
    }

    if (alertaBloqueada) {
      Serial.println(" -> [ESTADO: ALERTA ACTIVA / TRANSMITIENDO]");
    } else {
      Serial.println(" -> [ESTADO: OK / MODEM OFF]");
    }
  } else {
    Serial.println(" -> Buscando señal del sensor...");
  }

  // -----------------------------------------------------------
  // PASO 2: Disparo del Módem al detectar Alerta (Pin 21 HIGH)
  // -----------------------------------------------------------
  if (alertaBloqueada && !modemEncendido) {
    digitalWrite(MODEM_POWER_PIN, HIGH); // Encender alimentación del Módem
    delay(3000);                         // Espera de arranque de tensión

    if (encenderYConectarModem()) {
      modemEncendido = true;
      // Forzar primer envío inmediato
      ultimoEnvioThingSpeak = millis() - SEND_INTERVAL_MS; 
    } else {
      Serial.println("ERROR: Fallo al iniciar Módem. Reintentando...");
    }
  }

  // -----------------------------------------------------------
  // PASO 3: Telemetría continua a ThingSpeak (Cada 16 segundos)
  // -----------------------------------------------------------
  if (alertaBloqueada && modemEncendido) {
    if (millis() - ultimoEnvioThingSpeak >= SEND_INTERVAL_MS) {
      if (ultimaDistanciaValida > 0) {
        float voltaje = leerVoltajeFuente();

        // Verificar sesión GPRS
        if (!modem.isGprsConnected()) {
          Serial.println("Reconectando sesión GPRS...");
          modem.gprsConnect(apn, user, pass);
        }

        enviarThingSpeak(ultimaDistanciaValida, voltaje);
        ultimoEnvioThingSpeak = millis();
      }
    }
  }

  // -----------------------------------------------------------
  // PASO 4: Transición a Deep Sleep (SOLO si NO hubo alerta en 30s)
  // -----------------------------------------------------------
  if ((millis() - tiempoInicioCiclo >= TIEMPO_LECTURA_MS) && !alertaBloqueada) {
    Serial.println("\n------------------------------------------");
    Serial.println("30s transcurridos sin alerta (>1400 mm).");
    Serial.println("El módem nunca se encendió.");
    Serial.println("Apagando sensor y entrando en Deep Sleep (30s)...");
    Serial.println("------------------------------------------");

    // Asegurar apagar salidas antes de dormir
    digitalWrite(MODEM_POWER_PIN, LOW);
    digitalWrite(SENSOR_POWER_PIN, LOW);
    
    Serial.flush();

    esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
    esp_deep_sleep_start();
  }

  delay(200);
}

// =============================================================
// FUNCIONES AUXILIARES
// =============================================================

// Decodificación de trama UART DYP-A19
int leerDistanciaDYP() {
  while (SensorSerial.available() > 0) {
    SensorSerial.read();
  }

  SensorSerial.write(0x55); // Comando Trigger
  delay(50);

  uint8_t buffer[4];
  unsigned long timeout = millis();

  while (millis() - timeout < 400) {
    if (SensorSerial.available() >= 4) {
      if (SensorSerial.read() == 0xFF) {
        buffer[0] = 0xFF;
        buffer[1] = SensorSerial.read();
        buffer[2] = SensorSerial.read();
        buffer[3] = SensorSerial.read();

        uint8_t checksum = (buffer[0] + buffer[1] + buffer[2]) & 0xFF;
        if (checksum == buffer[3]) {
          return (buffer[1] << 8) + buffer[2];
        }
      }
    }
  }
  return -1;
}

// Lectura de voltaje con promedio para estabilidad
float leerVoltajeFuente() {
  long sumaADC = 0;
  int muestras = 20;

  for (int i = 0; i < muestras; i++) {
    sumaADC += analogRead(PIN_FUENTE);
    delay(2);
  }

  float promedioADC = (float)sumaADC / muestras;
  float voltajePin = (promedioADC / RESOLUCION_ADC) * VOLTAJE_REFERENCIA;
  return voltajePin * FACTOR_DIVISOR;
}

// Inicialización del SIM7600 y conexión a red Claro
bool encenderYConectarModem() {
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(1000);

  Serial.println("Inicializando comandos AT del módem SIM7600...");
  
  int intentos = 0;
  while (!modem.init() && intentos < 5) {
    delay(1000);
    intentos++;
  }

  if (intentos >= 5) {
    Serial.println("ERROR: Módem no responde AT.");
    return false;
  }

  modem.sendAT("+CSCLK=0"); // Inhabilitar Auto-Sleep del módulo
  modem.waitResponse();
  http.setTimeout(5000);

  Serial.println("Registrando en red celular Claro...");
  if (!modem.waitForNetwork(20000L)) {
    modem.sendAT("+CFUN=1"); // Forzar radio LTE
    modem.waitResponse();
    if (!modem.waitForNetwork(15000L)) {
      Serial.println("ERROR: Sin señal de red celular.");
      return false;
    }
  }

  Serial.println("Conectando APN igprs.claro.com.ar...");
  if (!modem.gprsConnect(apn, user, pass)) {
    Serial.println("ERROR: Fallo al activar datos GPRS.");
    return false;
  }

  Serial.println("¡CONEXIÓN 4G Y GPRS LISTAS!");
  return true;
}

// Petición HTTP GET hacia ThingSpeak
void enviarThingSpeak(int distancia, float voltaje) {
  int csq = modem.getSignalQuality();
  Serial.print("\n[ThingSpeak] Enviando -> Distancia: ");
  Serial.print(distancia);
  Serial.print(" mm | Voltaje: ");
  Serial.print(voltaje, 2);
  Serial.print(" V | CSQ: ");
  Serial.println(csq);

  String url = "/update?api_key=" + apiKey + 
               "&field1=" + String(distancia) + 
               "&field2=" + String(voltaje, 2);

  http.get(url);

  int statusCode = http.responseStatusCode();
  String response = http.responseBody();

  if (statusCode == 200 && response != "0") {
    Serial.print("-> Transmisión Correcta. Entry ID: ");
    Serial.println(response);
  } else {
    Serial.print("-> Error HTTP. Código: ");
    Serial.println(statusCode);
  }

  http.stop();
}
