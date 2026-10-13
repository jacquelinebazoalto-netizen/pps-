#define TINY_GSM_MODEM_SIM7600 

#include <Arduino.h> 
#include <TinyGsmClient.h> 

#define MODEM_POWER_PIN 21 
#define MODEM_TX 26 
#define MODEM_RX 27 

const char APN[] = "igprs.claro.com.ar"; 
const char AWS_ENDPOINT[] = "a1ycblwk8mm1bk-ats.iot.us-east-1.amazonaws.com"; 
const uint16_t AWS_PORT = 8883; 
const char MQTT_CLIENT_ID[] = "ESP32_Prueba"; 

// AWS Root CA 1
const char AWS_ROOT_CA[] = R"PEM(-----BEGIN CERTIFICATE-----
MIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsF
ADA5MQswCQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6
b24gUm9vdCBDQSAxMB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTEL
MAkGA1UEBhMCVVMxDzANBgNVBAoTBkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJv
b3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJ4gHHKeNXj
ca9HgFB0fW7Y14h29Jlo91ghYPl0hAEvrAIthtOgQ3pOsqTQNroBvo3bSMgHFzZM
9O6II8c+6zf1tRn4SWiw3te5djgdYZ6k/oI2peVKVuRF4fn9tBb6dNqcmzU5L/qw
IFAGbHrQgLKm+a/sRxmPUDgH3KKHOVj4utWp+UhnMJbulHheb4mjUcAwhmahRWa6
VOujw5H5SNz/0egwLX0tdHA114gk957EWW67c4cX8jJGKLhD+rcdqsq08p8kDi1L
93FcXmn/6pUCyziKrlA4b9v7LWIbxcceVOF34GfID5yHI9Y/QCB/IIDEgEw+OyQm
jgSubJrIqg0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC
AYYwHQYDVR0OBBYEFIQYzIU07LwMlJQuCFmcx7IQTgoIMA0GCSqGSIb3DQEBCwUA
A4IBAQCY8jdaQZChGsV2USggNiMOruYou6r4lK5IpDB/G/wkjUu0yKGX9rbxenDI
U5PMCCjjmCXPI6T53iHTfIUJrU6adTrCC2qJeHZERxhlbI1Bjjt/msv0tadQ1wUs
N+gDS63pYaACbvXy8MWy7Vu33PqUXHeeE6V/Uq2V8viTO96LXFvKWlJbYK8U90vv
o/ufQJVtMVT8QtPHRh8jrdkPSHCa2XV4cdFyQzR1bldZwgJcJmApzyMZFo6IQ6XU
5MsI+yMRQ+hDKXJioaldXgjUkK642M4UwtBV8ob2xJNDd2ZhwLnoQdeXeGADbkpy
rqXRfboQnoZsG4q5WTP468SQvvG5
-----END CERTIFICATE-----)PEM";

// Certificado del dispositivo
const char AWS_DEVICE_CERT[] = R"PEM(
-----BEGIN CERTIFICATE-----
MIIDWTCCAkGgAwIBAgIUdRk70RV/Qhe0tCeqY1u96IlqG+YwDQYJKoZIhvcNAQEL
BQAwTTFLMEkGA1UECwxCQW1hem9uIFdlYiBTZXJ2aWNlcyBPPUFtYXpvbi5jb20g
SW5jLiBMPVNlYXR0bGUgU1Q9V2FzaGluZ3RvbiBDPVVTMB4XDTI2MTAwOTIzMTc1
MloXDTQ5MTIzMTIzNTk1OVowHjEcMBoGA1UEAwwTQVdTIElvVCBDZXJ0aWZpY2F0
ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK2vyMyYQZq9sP3EC5zG
hR4nrFXaE5TvSkXjgGralDFuq2cYSlOUuPsolwjEhXUSjzKvIDOycADxjBN7oY
ct3kkeO2k7hOlvycn7Gwvj9ieurQl8CplmXmxaYsfUBPg3gCq00UA7iQlGB1Sp4x
4WQvsvK/1QyeHX4QeA4sy4gszht6h8q9DG1hBMd8zoB2wCvmdu3qDovh/7oN31Qw
s3jyct64In7Va90Jq5w0L/RFo8RZWlVJ+NPpAWDUw3lF5qFmeG2+CresUXqaPxoy
gqifvLvkRVn7oIWV06Mq8ctynzc7BW21zCKe+/H4WaiYG8yjOThPEc/5UbxaXZSR
b3sCAwEAAaNgMF4wHwYDVR0jBBgwFoAU/WVYQEFUYmBdQMSTgEXwYjB6/3EwHQYD
VR0OBBYEFBrdT7fMeTaN3Y8wacn8+2oXWyVmMAwGA1UdEwEB/wQCMAAwDgYDVR0P
AQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IBAQB2m87Xph2k2uUBI/ARMvE89wuR
5I133TrEUhdai5empC22K/A5+Y5Th9ouMW9cHD15V0UG9Mez1vgIHOZ/HgwTwETq
pbPftAc10H7ScmHJylLTyfoX7QkUAHrdjip0fG7mHb/Vth1QNTtG4tOznMjV8NHp
OsthbgmjZc050CefiRd787qPM0AAeq/1XTkHekZwiMsaKp4RZ2wG8ymX4POyJEVF
H+McLkAQ6X4kQbFw1XxE9x5Eq7xarEnvMaL96if7o8DbXOoIJuFs8Z/okkt92fcu
n6Y90zcJmmwZopNDMqAnlchBZ5s4XUDEk+pcLAR77XYMDORYQBw8yKZxoeb9
-----END CERTIFICATE-----
)PEM";

// Clave privada
const char AWS_PRIVATE_KEY[] = R"PEM(
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAra/IzJhBmr2w/cQLnMaFHiesVdoTlO9KReOAatqUMW6rZxhK
U5S4+yiXCMSFdRKPNVwq8gM7JwAPGME3uhhy3eSR47aTuE6W/JyfsbC+P2J66tCX
wKmWZebFpix9QE+DeAKrTRQDuJCUYHVKnjHhZC+y8r/VDJ4dfhB4DizLiCzOG3qH
yr0MbWEEx3zOgHbAK+Z27eoOi+H/ug3fVDCzePJy3rgiftVr3QmrnDQv9EWjxFla
VUn40+kBYNTDeUXmoWZ4bb4Kt6xRepo/GjKCqJ+8u+RFWfughZXToyrxy3KfNzsF
bbXMIp778fhZqJgbzKM5OE8Rz/lRvFpdlJFvewIDAQABAoIBAEiPXnDyzr2Jr85k
P4Gwgd5WLq3zHCklSr8lyvlY9X4tQNgiErMWN61diLN1/lcpeMCPD7XpWaXyZVwv
JEvPePVwTu510QK3emZwPFrsfp5WUwmUOUGY16ccoMfKYE0kqsTRQKVDzkYlyIb/
mTu7lPDY6IZ3U9cgmyuWT8GEP0dU2FVNfy6qk2DN3/+5d5QtPCFMOUTemxYeq+nc
FClotbxLAE9Pnh5zWiW7ImEQr4O4bsoVKJ+Qgf8BTzLVifOmI/uGIan+wKverTiK
9oDt5VR1anZEZpKdlMtruIXmvtkVMXHrkwQkumx4XUMz6Ga44j0LBaB8hcQWXCUs
IO4wcIkCgYEA1iAM3lcvraZHBwNC+aF/iAp0WGBCNVrongtlVE9NjH1c+sB9tm0m
W9LvH/8GC7gUHEIWgRkhRXISd9Az59vfRfkxmjcOXyyyLc7kEqkXMQbx4cRVLy4z
+Z82Q7hbvIjTXYF61MbNlUOLMcfWNUuIc4ZAtOEd2hTa7H1xJGmnsG8CgYEAz6c4
xcDEyeP0N9qYvi5oMfuJYJ8HkTAPYeIMHQvkT3NVsesVR2zE9vO3c1koHVSzb8q1
C7NmuZObQUbne2/FWU7+sOa1tEBgsRwSVqGOTjvuqZwwk3H9RY37EQAueHZDVsZk
24oZ9izfiwkueoxOIs0Sjo4+ufbwug6FYD0/37UCgYEAi7G1M4kl7eBBDm4uT7Xx
AcvwQ4fpKe35PMKqhOqH6VQQSPc0DMQA9n8SyokSZKrfU+A51leSwT++lLQcaPOl
In2EwtuQYL9EL2Z+nT37h1zEiUoRWQqHlh8sw9mO391UJ/jFLfPVQ8AhG4UIVxTE
HLpFlLwZQaHBgfAE1Ub9g7kCgYANVt6sxW9e0Mf1dpNtVCnZXCE9Fbo0t3OlhBHn
I8Zs3CnbHhDl37TfcFSOkmGjULeeLNVohQPKVBMbJGTmZw20aQCveIKfq6sKdZUv
/3zWxb7VInV0Y1QzzaUdOHfDwUUeI+yCteJpEATkN5jGwpCaZ7YTdkvNQnHAYgJr
ZkPeKQKBgQDEffXLpQC7H88TmrdtpIwdGhPeKQpAMMGszJS5eFEvK1gqWZK8dLYn
O13BeNraz7gh+HNE2uHkHUxSl/Vxnjba4CHN2ytD1nBZ9DVIOakQriiy0ZyYnrOY
ivSxzXKhfp4cxk0awrbSqiV7RjikSGeuPP+fTE4c1Vwc2fpi4Fxw4A==
-----END RSA PRIVATE KEY-----
)PEM";

HardwareSerial SerialAT(1);
TinyGsm modem(SerialAT);

String ejecutarAT(String cmd, unsigned long timeout = 2000) {
  Serial.print("\n[ENVIADO]: ");
  Serial.println(cmd);
  
  modem.sendAT(cmd);
  String resp = "";
  unsigned long t = millis();
  while (millis() - t < timeout) {
    while (SerialAT.available()) {
      char c = SerialAT.read();
      resp += c;
    }
  }
  Serial.print("[RESPUESTA]: ");
  Serial.println(resp);
  return resp;
}


bool descargarCertificadoNativo(const char* nombre, const char* contenido) {
  size_t len = strlen(contenido);

  // IMPORTANTE: sin "AT" al comienzo
  String cmd = "+CCERTDOWN=\"" + String(nombre) + "\"," + String(len);

  Serial.print("\n[CARGANDO CERTIFICADO]: ");
  Serial.println(nombre);
  Serial.print("Tamaño: ");
  Serial.print(len);
  Serial.println(" bytes");

  // Limpiar respuestas anteriores
  while (SerialAT.available()) SerialAT.read();

  modem.sendAT(cmd);

  // Esperar que el modem habilite la carga
  if (modem.waitResponse(5000L, ">") != 1) {
    Serial.println("ERROR: el modem no habilito la carga (>)");
    return false;
  }

  // Enviar el contenido del certificado
  SerialAT.write((const uint8_t*)contenido, len);

  // Esperar confirmacion
  if (modem.waitResponse(10000L) == 1) {
    Serial.println("Certificado cargado correctamente");
    return true;
  }

  Serial.println("ERROR: el modem no confirmo la carga");
  return false;
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n==================================================");
  Serial.println("   DIAGNOSTICO DE CONEXION SIM7600 <-> AWS IOT   ");
  Serial.println("==================================================");

  pinMode(MODEM_POWER_PIN, OUTPUT);
  digitalWrite(MODEM_POWER_PIN, HIGH);
  delay(3000);

  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);

  if (!modem.init()) {
    Serial.println("\nERROR GRAVE: El modem no responde a los comandos AT.");
    return;
  }
  Serial.println("\n1. Comunicacion AT con el modem: OK");

  if (modem.getSimStatus() != SIM_READY) {
    Serial.println("\nERROR CRITICO: Tarjeta SIM no detectada o con PIN.");
    return;
  }
  Serial.println("2. Tarjeta SIM detectada: OK");

  modem.waitForNetwork(30000L);
  ejecutarAT("+CTZU=1");
  ejecutarAT("+CCLK?");

  if (!modem.gprsConnect(APN, "", "")) {
    Serial.println("\nERROR: No se pudo establecer la conexion GPRS.");
    return;
  }
  Serial.println("3. Conexion GPRS activa: OK");

  // Carga de certificados mediante AT+CCERTDOWN
  Serial.println("\n--- Descargando certificados a la NVRAM con AT+CCERTDOWN ---");
  bool okCA = descargarCertificadoNativo("ca.pem", AWS_ROOT_CA);
  bool okCert = descargarCertificadoNativo("cert.pem", AWS_DEVICE_CERT);
  bool okKey = descargarCertificadoNativo("key.pem", AWS_PRIVATE_KEY);

  Serial.print(" - ca.pem: "); Serial.println(okCA ? "OK" : "FALLO");
  Serial.print(" - cert.pem: "); Serial.println(okCert ? "OK" : "FALLO");
  Serial.print(" - key.pem: "); Serial.println(okKey ? "OK" : "FALLO");

  // Configuración SSL
  Serial.println("\n--- Configurando Contexto SSL ---");
  ejecutarAT("+CSSLCFG=\"sslversion\",0,4");
  ejecutarAT("+CSSLCFG=\"authmode\",0,2");
  ejecutarAT("+CSSLCFG=\"cacert\",0,\"ca.pem\"");
  ejecutarAT("+CSSLCFG=\"clientcert\",0,\"cert.pem\"");
  ejecutarAT("+CSSLCFG=\"clientkey\",0,\"key.pem\"");
  ejecutarAT("+CSSLCFG=\"enableSNI\",0,1");
  ejecutarAT("+CSSLCFG?");

  // Secuencia de conexión MQTT
  Serial.println("\n--- Ejecutando Secuencia MQTT ---");
  ejecutarAT("+CMQTTDISC=0,120");
  ejecutarAT("+CMQTTREL=0");
  ejecutarAT("+CMQTTSTOP");
  ejecutarAT("+CMQTTSTART");
  
  
  ejecutarAT("+CMQTTACCQ=0,\"" + String(MQTT_CLIENT_ID) + "\",1");
 ejecutarAT("+CMQTTSSLCFG=0,0");
 ejecutarAT("+CMQTTSSLCFG?");
   modem.sendAT("+CSSLCFG?");
modem.waitResponse(3000L);
  Serial.println("\n--- Intentando Conexion Final con AWS Core ---");
  String cmdConn = "+CMQTTCONNECT=0,\"tcp://" + String(AWS_ENDPOINT) + ":" + String(AWS_PORT) + "\",60,1";
  String respConn = ejecutarAT(cmdConn, 15000);

  Serial.println("\n==================================================");
  Serial.println("              RESULTADO DE LA PRUEBA              ");
  Serial.println("==================================================");

  if (respConn.indexOf("+CMQTTCONNECT: 0,0") != -1) {
    Serial.println("SUCCESS: Conexion establecida con exito con AWS IoT!");
  } else {
    Serial.println("FAIL: La conexion fallo.");
     ejecutarAT("+CGMR");
ejecutarAT("+CCERTDOWN=?");
ejecutarAT("+CCERTLIST");
ejecutarAT("+CMQTTCFG=?");
  }
 
}

void loop() {
}
