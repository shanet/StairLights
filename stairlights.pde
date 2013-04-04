#include "SPI.h"
#include "Adafruit_WS2801.h"

#define IR_DETECT_UPSTAIRS_PIN     2
#define IR_DETECT_DOWNSTAIRS_PIN   4

#define LIGHTS_DATA_PIN  6 // Yellow wire
#define LIGHTS_CLOCK_PIN 7 // Green wire

#define NUM_PIXELS 25
#define IR_KHZ     38

#define RED     1
#define GREEN   4
#define BLUE    5

#define UP   0
#define DOWN 1

/*#ifdef F_CPU
  #define SYSCLOCK F_CPU     // main Arduino clock
#else
  #define SYSCLOCK 16000000  // main Arduino clock
#endif*/

#define TIMER_PWM_PIN        3 
#define TIMER_ENABLE_PWM     (TCCR2A |= _BV(COM2B1))
#define TIMER_DISABLE_PWM    (TCCR2A &= ~(_BV(COM2B1)))
#define TIMER_DISABLE_INTR   (TIMSK2 = 0)
#define TIMER_ENABLE_INTR    (TIMSK2 = _BV(OCIE2A))

Adafruit_WS2801 lights = Adafruit_WS2801((uint16_t)NUM_PIXELS, (uint8_t)LIGHTS_DATA_PIN, (uint8_t)LIGHTS_CLOCK_PIN, (uint8_t)WS2801_GRB);

void setup() {
   Serial.begin(9600);

   pinMode(IR_DETECT_UPSTAIRS_PIN, INPUT);
   pinMode(IR_DETECT_DOWNSTAIRS_PIN, INPUT);

   enableIROut(IR_KHZ);

   lights.begin();
   lights.show();

   randomSeed(analogRead(0));
}

void loop() {
   if(!digitalRead(IR_DETECT_UPSTAIRS_PIN)) {
      show_stair_lights(DOWN);
   } else if(!digitalRead(IR_DETECT_DOWNSTAIRS_PIN)) {
      show_stair_lights(UP);
   }

   // Sleep for 5 seconds to ensure slow walkers get up the stairs before checking for beam breaks again
   //delay(5000);
}


void enableIROut(int khz) {
   // Disable the Timer2 Interrupt (which is used for receiving IR)
   TIMER_DISABLE_INTR; //Timer2 Overflow Interrupt
  
   pinMode(TIMER_PWM_PIN, OUTPUT);
   digitalWrite(TIMER_PWM_PIN, LOW); // When not sending PWM, we want it low
  
   // The top value for the timer.  The modulation frequency will be SYSCLOCK / 2 / OCR2A.
   const uint8_t pwmval = F_CPU / 2000 / IR_KHZ;

   TCCR2A = _BV(WGM20);
   TCCR2B = _BV(WGM22) | _BV(CS20);
   OCR2A  = pwmval;
   OCR2B  = pwmval / 3;

   TIMER_ENABLE_PWM; // Enable pin 3 PWM output
}


void show_stair_lights(int direction) {
   int pattern = random(0, 3);

   switch(pattern) {
      case 0:
         fadeColor(RED, direction);
         break;
      case 1:
         fadeColor(GREEN, direction);
         break;
      case 2:
         fadeColor(BLUE, direction);
         break;
   }
}


void fadeColor(int color, int direction) {
   int start_pixel;
   int end_pixel;

   switch(direction) {
      case UP:
         start_pixel = lights.numPixels();
         end_pixel = 0;
         break;
      case DOWN:
         start_pixel = 0;
         end_pixel = lights.numPixels();
         break;
   }

   for(int i=start_pixel; (direction == UP ? i>end_pixel : i<end_pixel); (direction == DOWN ? i++ : i--)) {
      for(int j=0; j<=10; j++) {
         uint32_t color_info;

         switch(color) {
            case RED:
               color_info = createColor((float)255/10*j, 0, 0);
               break;
            case GREEN:
               color_info = createColor(0, (float)255/10*j, 0);
               break;
            case BLUE:
               color_info = createColor(0, 0, (float)255/10*j);
               break;
         }

         lights.setPixelColor(i, color_info);
         lights.show();
         delay(3);
      }
      delay(5);
   }

   delay(200);

   for(int i=start_pixel; (direction == UP ? i>end_pixel : i<end_pixel); (direction == DOWN ? i++ : i--)) {
      for(int j=0; j<=10; j++) {
         uint32_t color_info;

         switch(color) {
            case RED:
               color_info = createColor(255 - ((float)255/10*j), 0, 0);
               break;
            case GREEN:
               color_info = createColor(0, 255 - ((float)255/10*j), 0);
               break;
            case BLUE:
               color_info = createColor(0, 0, 255 - ((float)255/10*j));
               break;
         }

         lights.setPixelColor(i, color_info);
         lights.show();
         delay(3);
      }
      delay(5);
   }

}

void rainbow(uint8_t wait) {
   for(int i=0; i<256; i++) {     // 3 cycles of all 256 colors in the wheel
      for(int j=0; j<lights.numPixels(); j++) {
         lights.setPixelColor(j, Wheel((i + j) % 255));
      }  

      lights.show();
      delay(wait);
   }
}


void rainbowCycle(uint8_t wait) {
   for(int i=0; i<256 * 5; i++) {     // 5 cycles of all 25 colors in the wheel
      for(int j=0; j<lights.numPixels(); j++) {
         // tricky math! we use each pixel as a fraction of the full 96-color wheel
         // (thats the i / lights.numPixels() part)
         // Then add in j which makes the colors go around per pixel
         // the % 96 is to make the wheel cycle around
         lights.setPixelColor(j, Wheel( ((j * 256 / lights.numPixels()) + i) % 256) );
      }  

      lights.show();
      delay(wait);
   }
}


// Create a 24 bit color value from R,G,B
uint32_t createColor(byte red, byte green, byte blue) {
   uint32_t color;

   color = red;
   color <<= 8;
   color |= green;
   color <<= 8;
   color |= blue;

   return color;
}


//Input a value 0 to 255 to get a color value.
//The colours are a transition r - g -b - back to r
uint32_t Wheel(byte WheelPos) {
   if(WheelPos < 85) {
      return createColor(WheelPos * 3, 255 - WheelPos * 3, 0);
   } else if(WheelPos < 170) {
      WheelPos -= 85;
      return createColor(255 - WheelPos * 3, 0, WheelPos * 3);
   } else {
      WheelPos -= 170; 
      return createColor(0, WheelPos * 3, 255 - WheelPos * 3);
   }
}