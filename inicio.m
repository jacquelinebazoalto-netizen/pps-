#include <HardwareSerial.h>

// --- PINES ---
#define LED_ALERT_PIN 21     // LED en GPIO 2
#define SENSOR_POWER_PIN 5  // Pin D5 como VCC (alimentación) del sensor
#define SENSOR_RX 16        // ESP32 RX2 <- Conectar a Sensor TX
#define SENSOR_TX 17        // ESP32 TX2 -> Conectar a Sensor RX

// --- CONFIGURACIÓN DE TIEMPOS Y UMBRAL ---
#define UMBRAL_DISTANCIA 1400        // Distancia límite en mm
#define TIEMPO_LECTURA_MS 30000      // 30 segundos de muestreo inicial
#define TIME_TO_SLEEP 30             // 30 segundos DORMIDO (Deep Sleep)
#define uS_TO_S_FACTOR 1000000ULL    // Conversión de microsegundos a segundos

// Usamos el puerto serie de hardware 2 del ESP32
HardwareSerial SensorSerial(2);

// Prototipo de la función
int leerDistanciaDYP();

void setup() {
  // 1. Inicializar consola Serie
  Serial.begin(115200);
  delay(500); 
  Serial.println("\n==========================================");
  Serial.println("--- ESP32 DESPIERTO: Iniciando lecturas ---");
  Serial.println("==========================================");

  // Configurar pines
  pinMode(LED_ALERT_PIN, OUTPUT);
  digitalWrite(LED_ALERT_PIN, LOW); // LED apagado por defecto

  pinMode(SENSOR_POWER_PIN, OUTPUT);
  digitalWrite(SENSOR_POWER_PIN, HIGH); // Encender alimentación del sensor
  
  // Tiempo de arranque del sensor aumentado (1.5 segundos)
  delay(1500); 

  // 2. Inicializar comunicación UART con el sensor
  SensorSerial.begin(9600, SERIAL_8N1, SENSOR_RX, SENSOR_TX);

  // Variables de control
  unsigned long tiempoInicio = millis();
  bool alertaBloqueada = false; // Latch permanente de la alerta

  // 3. Bucle de muestreo
  while (true) {
    int distancia = leerDistanciaDYP();

    if (distancia > 0) {
      Serial.print("Distancia medida: ");
      Serial.print(distancia);
      Serial.print(" mm");

      // Verificación de la condición de disparo (> 1400 mm)
      if (distancia > UMBRAL_DISTANCIA) {
        alertaBloqueada = true; // Activa el bloqueo permanente
      }

      if (alertaBloqueada) {
        digitalWrite(LED_ALERT_PIN, HIGH);
        Serial.println(" -> [ALERTA BLOQUEADA: LED ENCENDIDO / NO SLEEP]");
      } else {
        Serial.println(" -> [OK]");
      }
    } else {
      Serial.println(" -> Error / Buscando señal...");
    }

    // SALIDA A DEEP SLEEP:
    // SOLO si ya pasaron los 30 segundos Y la alerta NUNCA se ha activado
    if ((millis() - tiempoInicio >= TIEMPO_LECTURA_MS) && !alertaBloqueada) {
      break; // Sale del bucle para ir a dormir
    }

    delay(300); // Frecuencia de muestreo
  }

  // 4. Si sale del bucle significa que transcurrieron los 30s sin ninguna alerta
  Serial.println("\n------------------------------------------");
  Serial.println("30 segundos completados sin alertas.");
  Serial.println("Apagando sensor y entrando en Deep Sleep (30 seg)...");
  Serial.println("------------------------------------------");
  
  digitalWrite(LED_ALERT_PIN, LOW);    // Asegura LED apagado
  digitalWrite(SENSOR_POWER_PIN, LOW); // Apaga el sensor
  Serial.flush();

  // Entrar en Deep Sleep
  esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
  esp_deep_sleep_start();
}

void loop() {
  // Nunca llega aquí en Deep Sleep
}

// Función mejorada para procesar la trama UART del sensor DYP-A19
int leerDistanciaDYP() {
  // Limpia buffers residuales antes de solicitar/leer
  while (SensorSerial.available() > 0) {
    SensorSerial.read();
  }

  // Enviar comando Trigger 0x55 por si la versión de tu sensor lo requiere
  SensorSerial.write(0x55); 
  delay(50); // Breve espera para respuesta del sensor

  uint8_t buffer[4];
  unsigned long timeout = millis();

  while (millis() - timeout < 400) { // Timeout de lectura de 400ms
    if (SensorSerial.available() >= 4) {
      if (SensorSerial.read() == 0xFF) { // Byte de cabecera
        buffer[0] = 0xFF;
        buffer[1] = SensorSerial.read(); // Byte Alto
        buffer[2] = SensorSerial.read(); // Byte Bajo
        buffer[3] = SensorSerial.read(); // Checksum

        // Validar Checksum: (0xFF + DataHigh + DataLow) & 0xFF
        uint8_t checksum = (buffer[0] + buffer[1] + buffer[2]) & 0xFF;

        if (checksum == buffer[3]) {
          return (buffer[1] << 8) + buffer[2]; // Distancia en mm
        }
      }
    }
  }
  return -1; // Fallo de lectura
}
