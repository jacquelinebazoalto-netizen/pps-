#define TINY_GSM_MODEM_SIM7600 // Cambiar a A7672X si tu placa usa ese chip específico

#include <Arduino.h>
#include <TinyGsmClient.h>

#define SerialAT Serial1

#define MODEM_TX 26
#define MODEM_RX 27

// Claro Argentina
const char apn[]  = "igprs.claro.com.ar";
const char user[] = "";
const char pass[] = "";

// ThingSpeak
String apiKey = "UC6FXJB6RIPJH2NB";

TinyGsm modem(SerialAT);
TinyGsmClient client(modem);

void setup() {
  Serial.begin(115200);

  // Inicialización del puerto Serie con el módem
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(3000);

  Serial.println("Inicializando modem...");
  if (!modem.init()) {
    Serial.println("ERROR: No se pudo comunicar con el modem (Revisa TX/RX y alimentación).");
    while (1);
  }
  Serial.println("MODEM OK");

  Serial.println("Esperando red celular...");
  if (!modem.waitForNetwork()) {
    Serial.println("ERROR: No hay cobertura o falla la SIM.");
    while (1);
  }
  Serial.println("RED OK");

  Serial.println("Conectando datos moviles...");
  if (!modem.gprsConnect(apn, user, pass)) {
    Serial.println("ERROR: Fallo al conectar GPRS/APN.");
    while (1);
  }
  Serial.println("INTERNET OK");
}

void loop() {
  float temperatura = 200.0; // Cambiar por la lectura real del sensor

  // Verificar que la conexión a internet siga activa
  if (!modem.isGprsConnected()) {
    Serial.println("Conexion perdida. Reconectando...");
    modem.gprsConnect(apn, user, pass);
  }

  Serial.println("\nConectando a ThingSpeak...");

  if (client.connect("api.thingspeak.com", 80)) {

    // Se eliminó el "56" sobrante
    String url = "/update?api_key=" + apiKey + "&field1=" + String(temperatura, 1);

    // Formato HTTP/1.1 estándar
    client.print("GET ");
    client.print(url);
    client.println(" HTTP/1.1");
    client.println("Host: api.thingspeak.com");
    client.println("Connection: close");
    client.println(); // Línea en blanco obligatoria al final del header HTTP

    Serial.println("Peticion enviada. Esperando respuesta...");

    unsigned long timeout = millis();

    // Esperar y mostrar la respuesta del servidor en la consola Serie
    while (client.connected() && millis() - timeout < 10000) {
      while (client.available()) {
        char c = client.read();
        Serial.write(c);
        timeout = millis();
      }
    }

    client.stop();
    Serial.println("\nConexion cerrada.");
  } else {
    Serial.println("ERROR: No se pudo abrir el socket TCP con api.thingspeak.com");
  }

  // Espera 20 segundos antes del próximo envío
  delay(20000);
}
