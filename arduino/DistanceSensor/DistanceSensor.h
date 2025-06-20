#ifndef DISTANCESENSOR_H
#define DISTANCESENSOR_H

class DistanceSensor {
  public:
    DistanceSensor(int trigPin, int echoPin);
    void begin();
    float getDistanceCM();

  private:
    int _trigPin;
    int _echoPin;
};

#endif
