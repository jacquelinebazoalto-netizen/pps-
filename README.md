# pps-
#define TINY_GSM_MODEM_A7672X

#include <TinyGsmClient.h>
#include <PubSubClient.h>

#define SerialMon Serial
#define SerialAT Serial1

// UART ESP32 <-> A7670
#define MODEM_TX 26
#define MODEM_RX 27

// APN Claro Argentina
const char apn[]      = "igprs.claro.com.ar";
const char gprsUser[] = "";
const char gprsPass[] = "";

// MQTT
const char* mqtt_server = "mqtt.iotbhai.io";
const int mqtt_port = 1883;
const char* mqtt_user = "user1";
const char* mqtt_pass = "user1";

const char* pubTopic = "device/status";
const char* subTopic = "device/command";

TinyGsm modem(SerialAT);
TinyGsmClient gsmClient(modem);
PubSubClient mqtt(gsmClient);

unsigned long lastSend = 0;

void callback(char* topic, byte* payload, unsigned int length)
{
  Serial.print("Mensaje recibido: ");

  for (unsigned int i = 0; i < length; i++)
    Serial.print((char)payload[i]);

  Serial.println();
}

void conectarMQTT()
{
  while (!mqtt.connected())
  {
    Serial.print("Conectando MQTT... ");

    if (mqtt.connect("ESP32_A7670", mqtt_user, mqtt_pass))
    {
      Serial.println("OK");
      mqtt.subscribe(subTopic);
    }
    else
    {
      Serial.print("Error MQTT: ");
      Serial.println(mqtt.state());
      delay(5000);
    }
  }
}

void setup()
{
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("======== A7670 MQTT ========");

  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);

  delay(3000);

  Serial.println("Inicializando modem...");

  if (!modem.init())
  {
    Serial.println("ERROR inicializando modem");
    while (1);
  }

  Serial.println("Modem OK");

  Serial.print("Modelo: ");
  Serial.println(modem.getModemInfo());

  Serial.println("Esperando red...");

  if (!modem.waitForNetwork(60000))
  {
    Serial.println("No hay red");
    while (1);
  }

  Serial.println("Red OK");

  Serial.print("Operador: ");
  Serial.println(modem.getOperator());

  Serial.print("CSQ: ");
  Serial.println(modem.getSignalQuality());

  Serial.println("Conectando GPRS...");

  // Intentar conectar
  modem.gprsConnect(apn, gprsUser, gprsPass);

  delay(5000);

  bool red = modem.isNetworkConnected();
  bool gprs = modem.isGprsConnected();

  Serial.print("Registrado en red: ");
  Serial.println(red);

  Serial.print("GPRS conectado: ");
  Serial.println(gprs);

  Serial.print("IP: ");
  Serial.println(modem.localIP());

  if (!gprs)
  {
    Serial.println("ERROR GPRS");
    while (1);
  }

  Serial.println("GPRS OK");

  mqtt.setServer(mqtt_server, mqtt_port);
  mqtt.setCallback(callback);
}

void loop()
{
  if (!mqtt.connected())
    conectarMQTT();

  mqtt.loop();

  if (millis() - lastSend > 10000)
  {
    lastSend = millis();

    if (mqtt.publish(pubTopic, "Hola desde ESP32 + A7670"))
      Serial.println("Mensaje enviado");
    else
      Serial.println("Error al publicar");
  }
}
