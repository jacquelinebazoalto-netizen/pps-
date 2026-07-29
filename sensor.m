#include <Arduino.h>

#define SENSOR_RX 16   // ESP32 recibe del TX del sensor
#define SENSOR_TX 17   // ESP32 transmite al RX del sensor

HardwareSerial SensorSerial(2);

void setup() {

  Serial.begin(115200);

  SensorSerial.begin(9600, SERIAL_8N1, SENSOR_RX, SENSOR_TX);

  Serial.println("DYP-A19 prueba");

}


void loop() {

  if (SensorSerial.available() >= 4) {

    uint8_t datos[4];

    SensorSerial.readBytes(datos, 4);


    // Trama DYP-A19:
    // Byte 0 = 0xFF
    // Byte 1 = distancia alta
    // Byte 2 = distancia baja
    // Byte 3 = checksum

    if (datos[0] == 0xFF) {

      int distancia = datos[1] * 256 + datos[2];

      Serial.print("Distancia: ");
      Serial.print(distancia);
      Serial.println(" mm");

    }

  }

}
