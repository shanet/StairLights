#include "SPI.h"
#include "Adafruit_WS2801.h"

#define IR_DETECT_UPSTAIRS_PIN     2
#define IR_DETECT_DOWNSTAIRS_PIN   4

#define LIGHTS_DATA_PIN  6 // Yellow wire
#define LIGHTS_CLOCK_PIN 7 // Green wire

#define NUM_PIXELS 25
#define IR_KHZ     38

/*#define RED     0
#define ORANGE  1
#define YELLOW  2
#define GREEN   3
#define BLUE    4
#define PURPLE  5*/

// Color options
#define MULTI  0
#define RED    1
#define ORANGE 2
#define YELLOW 3
#define GREEN  4
#define BLUE   5
#define PURPLE 6
#define WHITE  7
#define COOL   8

// Rotation speed options
#define ROT_NONE      0
#define ROT_VERY_SLOW 1
#define ROT_SLOW      2
#define ROT_NORMAL    3
#define ROT_FAST      4
#define ROT_VERY_FAST 5

// Fade speed options
#define FADE_NONE      0
#define FADE_VERY_SLOW 1
#define FADE_SLOW      2
#define FADE_NORMAL    3
#define FADE_FAST      4
#define FADE_VERY_FAST 5

// Rotation direction options
#define ROT_CW  0
#define ROT_CCW 1

// Shadow length options
#define SDW_NONE       0
#define SDW_VERY_SMALL 1
#define SDW_SMALL      2
#define SDW_NORMAL     3
#define SDW_LONG       4
#define SDW_VERY_LONG  5

#define UP   0
#define DOWN 1

#define TIMER_PWM_PIN        3 
#define TIMER_ENABLE_PWM     (TCCR2A |= _BV(COM2B1))
#define TIMER_DISABLE_PWM    (TCCR2A &= ~(_BV(COM2B1)))
#define TIMER_DISABLE_INTR   (TIMSK2 = 0)
#define TIMER_ENABLE_INTR    (TIMSK2 = _BV(OCIE2A))

int color;            // Selected color
int rotationSpeed;    // Selected rotation speed
int rotationDir;      // Selected rotation direction
int shadowLength;     // Selected shadow length
int fadeSpeed;        // If the solid flag was selected

Adafruit_WS2801 lights = Adafruit_WS2801((uint16_t)NUM_PIXELS, (uint8_t)LIGHTS_DATA_PIN, (uint8_t)LIGHTS_CLOCK_PIN, (uint8_t)WS2801_GRB);

void setup() {
   Serial.begin(9600);

   pinMode(IR_DETECT_UPSTAIRS_PIN, INPUT);
   pinMode(IR_DETECT_DOWNSTAIRS_PIN, INPUT);

   enableIrTransmitters(IR_KHZ);

   lights.begin();
   lights.show();

   randomSeed(analogRead(0));

   //delay(1000);
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


void show_stair_lights(int direction) {
   int pattern = random(0, 5);
   //pattern = 3;

   switch(pattern) {
      case 0:
         basic_color(direction);
         break;
      case 1:
         rainbow(75);
         break;
      case 2:
         rainbow_cycle(direction, 2, 20);
         break;
      case 3:
         colorswirl(direction, 10000);
         break;
      case 4:
         runner(direction, 10, 50);
         break;
   }
}


void basic_color(int direction) {
   unsigned char red   = 0;
   unsigned char green = 0;
   unsigned char blue  = 0;

   get_random_color(&red, &green, &blue);

   int steps      = 10;
   int delay_time = 5;
   run_color(0, red, 0, green, 0, blue, steps, direction, delay_time);

   delay(1000);

   // Pick a new color to fade to
   unsigned char new_red   = 0;
   unsigned char new_green = 0;
   unsigned char new_blue  = 0;
   get_random_color(&new_red, &new_green, &new_blue);

   // Fade to the new color
   delay_time = 150;
   fade_color(red, new_red, green, new_green, blue, new_blue, steps, delay_time);

   delay(1000);

   // Fade out more slowly
   steps      = 100;
   delay_time = 40;
   run_color(new_red, 0, new_green, 0, new_blue, 0, steps, direction, delay_time);
}


void run_color(unsigned char old_red, unsigned char new_red, unsigned char old_green, unsigned char new_green, 
               unsigned char old_blue, unsigned char new_blue, int steps, int direction, int delay_time) {
   int start_pixel;
   int end_pixel;
   get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

   float red_step   = (float)(new_red   - old_red)   / steps;
   float green_step = (float)(new_green - old_green) / steps;
   float blue_step  = (float)(new_blue  - old_blue)  / steps;

   for(int i=start_pixel; (direction == UP ? i>=end_pixel : i<end_pixel); (direction == DOWN ? i++ : i--)) {
      float cur_red   = old_red;
      float cur_green = old_green;
      float cur_blue  = old_blue;

      for(int j=0; j<steps; j++) {
         cur_red   += red_step;
         cur_green += green_step;
         cur_blue  += blue_step;

         lights.setPixelColor(i, (unsigned char)cur_red, (unsigned char)cur_green, (unsigned char)cur_blue);
         lights.show();

         delay(6);
      }

      delay(delay_time);
   }
}


void fade_color(unsigned char old_red, unsigned char new_red, unsigned char old_green, unsigned char new_green, 
                unsigned char old_blue, unsigned char new_blue, int steps, int delay_time) {

   float red_step   = (float)(new_red   - old_red)   / steps;
   float green_step = (float)(new_green - old_green) / steps;
   float blue_step  = (float)(new_blue  - old_blue)  / steps;

   float cur_red   = old_red;
   float cur_green = old_green;
   float cur_blue  = old_blue;

   for(int i=0; i<steps; i++) {
      cur_red   += red_step;
      cur_green += green_step;
      cur_blue  += blue_step;

      for(int j=0; j<lights.numPixels(); j++) {
         lights.setPixelColor(j, (unsigned char)cur_red, (unsigned char)cur_green, (unsigned char)cur_blue);
      }

      lights.show();

      delay(delay_time);
   }
}


void rainbow(uint8_t wait) {
   // 3 cycles of all 256 colors in the color_wheel
   int brightness;
   for(int i=0; i<256; i++) {
      for(int j=0; j<lights.numPixels(); j++) {
         if(i<50) {
            brightness = 1 - 1/(i+1);
         } else if(i>206) {
            brightness = 1/(256-i);
         }

         lights.setPixelColor(j, brightness * color_wheel((i + j) % 255));
      }  

      lights.show();
      delay(wait);
   }
}


void rainbow_cycle(int direction, int num_cycles, int delay_time) {
   int start_pixel;
   int end_pixel;
   get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

   for(int i=start_pixel; (direction == UP ? i>=end_pixel : i<end_pixel); (direction == DOWN ? i++ : i--)) {
      uint32_t color = color_wheel((i * 256 / lights.numPixels()) % 256);
      lights.setPixelColor(i, color);
      lights.show();

      delay(delay_time*4);
   }

   for(int i=0; i<256 * num_cycles; i++) {
      for(int j=0; j<lights.numPixels(); j++) {
         // we use each pixel as a fraction of the full 96-color color_wheel
         // (thats the i / lights.numPixels() part)
         // Then add in j which makes the colors go around per pixel
         // the % 96 is to make the color_wheel cycle around
         uint32_t color = color_wheel(((j * 256 / lights.numPixels()) + i) % 256);
         lights.setPixelColor(j, color);
      }  

      lights.show();
      delay(delay_time);
   }

   for(int i=start_pixel; (direction == UP ? i>=end_pixel : i<end_pixel); (direction == DOWN ? i++ : i--)) {
      lights.setPixelColor(i, 0);  
      lights.show();

      delay(delay_time*4);
   }
}


void runner(int direction, int cycles, int delay_time) {
   unsigned char red   = 0;
   unsigned char green = 0;
   unsigned char blue  = 0;
   get_random_color(&red, &green, &blue);

   int start_pixel;
   int end_pixel;

   for(int i=0; i<cycles; i++) {
      if(i != 0) {
         if(direction == UP) {
            direction = DOWN;
         } else {
            direction = UP;
         }
      }
      get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

      for(int j=start_pixel; (direction == UP ? j>=end_pixel : j<end_pixel); (direction == DOWN ? j++ : j--)) {
         for(int k=0; k<lights.numPixels(); k++) {
            if(j != k) {
               lights.setPixelColor(k, 0);
            }
         }

         lights.setPixelColor(j, red, green, blue);
         lights.setPixelColor(j+1, red, green, blue);
         lights.show();

         delay(delay_time);
      }
   }

   for(int i=0; i<lights.numPixels(); i++) {
      lights.setPixelColor(i, 0);
      lights.show();
   }
}

void colorswirl(int direction, int run_time) {
   color            = MULTI;
   rotationSpeed    = ROT_VERY_FAST;
   shadowLength     = SDW_VERY_SMALL;
   fadeSpeed        = FADE_NONE;

   switch(direction) {
      case UP:
         rotationDir = ROT_CCW;
         break;
      case DOWN:
         rotationDir = ROT_CW;
         break;
   }

   int start_time = millis();

   while(start_time + run_time > millis()) {
      get_colorswirl_data();
      lights.show();
   }

   for(int i=0; i<lights.numPixels(); i++) {
      lights.setPixelColor(i, 0);
   }
   lights.show();
}


void get_colorswirl_data(void) {
   static int brightness        = 0;
   static double shadowPosition = 0;
   static double lightPosition  = 0;
   static int hue               = 0;

   static unsigned char red;
   static unsigned char green;
   static unsigned char blue;

   shadowPosition = lightPosition;

   for(int i=0; i<lights.numPixels(); i++) {
      getLedColor(&red, &green, &blue, hue);

      // Resulting hue is multiplied by brightness in the
      // range of 0 to 255 (0 = off, 255 = brightest).
      // Gamma corrrection (the 'pow' function here) adjusts
      // the brightness to be more perceptually linear.
      brightness = (shadowLength != SDW_NONE || rotationSpeed != ROT_NONE) ? (int)(pow(0.5 + sin(shadowPosition) * 0.5, 3.0) * 255.0) : 255;

      lights.setPixelColor(i, create_color((red * brightness) / 255, (green * brightness) / 255, (blue * brightness) / 255));

      // Each pixel is offset in both hue and brightness
      updateShadowPosition(&shadowPosition);
   }

   // If color is multi and fade flag was selected, do a slow fade between colors with the rot speed
   if(fadeSpeed != FADE_NONE && color == MULTI) {
      switch(fadeSpeed) {
         case FADE_VERY_SLOW:
         delay(180);
         break;
         case FADE_SLOW:
         delay(130);
         break;
         default:
         case FADE_NORMAL:
         delay(90);
         break;
         case FADE_FAST:
         delay(30);
         break;
         case FADE_VERY_FAST:
         delay(10);
         break;
      }
   }

   // Slowly rotate hue and brightness in opposite directions
   updateHue(&hue);
   updateLightPosition(&lightPosition);
}


void getLedColor(unsigned char *r, unsigned char *g, unsigned char *b, int curHue) {
    static unsigned char _r;
    static unsigned char _g;
    static unsigned char _b;
    static unsigned char lo;

    switch(color) {
        case MULTI:
            // Fixed-point hue-to-RGB conversion.  'hue2' is an
            // integer in the range of 0 to 1535, where 0 = red,
            // 256 = yellow, 512 = green, etc.  The high byte
            // (0-5) corresponds to the sextant within the color
            // wheel, while the low byte (0-255) is the
            // fractional part between primary/secondary colors.
            lo = curHue & 255;

            switch((curHue >> 8) % 6) {
                case 0:
                    _r = 255;
                    _g = lo;
                    _b = 0;
                    break;
                case 1:
                    _r = 255 - lo;
                    _g = 255;
                    _b = 0;
                    break;
                case 2:
                    _r = 0;
                    _g = 255;
                    _b = lo;
                    break;
                case 3:
                    _r = 0;
                    _g = 255 - lo;
                    _b = 255;
                    break;
                case 4:
                    _r = lo;
                    _g = 0;
                    _b = 255;
                    break;
                case 5:
                    _r = 255;
                    _g = 0;
                    _b = 255 - lo;
                    break;
            }

            curHue += 40;
            break;
        case RED:
            _r = 255;
            _g = 0;
            _b = 0;
            break;
        case ORANGE:
            _r = 255;
            _g = 165;
            _b = 0;
            break;
        case YELLOW:
            _r = 255;
            _g = 255;
            _b = 0;
            break;
        case GREEN:
            _r = 0;
            _g = 255;
            _b = 0;
            break;
        case BLUE:
            _r = 0;
            _g = 0;
            _b = 255;
            break;
        case PURPLE:
            _r = 128;
            _g = 0;
            _b = 128;
            break;
        case COOL:
            lo = curHue & 255;

            switch((curHue >> 8) % 6) {
                case 0:
                    _r = 0;
                    _g = lo;
                    _b = 0;
                    break;
                case 1:
                    _r = 0;
                    _g = 255;
                    _b = 0;
                    break;
                case 2:
                    _r = 0;
                    _g = 255;
                    _b = lo;
                    break;
                case 3:
                    _r = 0;
                    _g = 255 - lo;
                    _b = 255;
                    break;
                case 4:
                    _r = 0;
                    _g = 0;
                    _b = 255;
                    break;
                case 5:
                    _r = 0;
                    _g = 0;
                    _b = 255 - lo;
                    break;
            }

            curHue += 40;
            break;

        case WHITE:
        default:
            _r = 255;
            _g = 255;
            _b = 255;
    }

    *r = _r;
    *g = _g;
    *b = _b;
}


void updateLightPosition(double *lightPosition) {
    switch(rotationSpeed) {
        case ROT_NONE:
            *lightPosition = 0;
            break;
        case ROT_VERY_SLOW:
            *lightPosition += (rotationDir == ROT_CW) ? -.007 : .007;
            break;
        case ROT_SLOW:
            *lightPosition += (rotationDir == ROT_CW) ? -.015 : .015;
            break;
        case ROT_NORMAL:
        default:
            *lightPosition += (rotationDir == ROT_CW) ? -.03 : .03;
            break;
        case ROT_FAST:
            *lightPosition += (rotationDir == ROT_CW) ? -.045 : .045;
            break;
        case ROT_VERY_FAST:
            *lightPosition += (rotationDir == ROT_CW) ? -.07 : .07;
            break;
    }
}


void updateShadowPosition(double *shadowPosition) {
    switch(shadowLength) {
        case SDW_NONE:
            *shadowPosition += 0;
            break;
        case SDW_VERY_SMALL:
            *shadowPosition += 0.9;
            break;
        case SDW_SMALL:
            *shadowPosition += 0.6;
            break;
        case SDW_NORMAL:
        default:
            *shadowPosition += 0.3;
            break;
        case SDW_LONG:
            *shadowPosition += 0.2;
            break;
        case SDW_VERY_LONG:
            *shadowPosition += 0.08;
            break;
    }
}


void updateHue(int *curHue) {
    static int hue = 0;
    *curHue = hue = (hue + 5) % 1536;
}



void get_random_color(unsigned char *red, unsigned char *green, unsigned char *blue) {
   int color = random(RED, PURPLE+1);

   *red   = 0;
   *green = 0;
   *blue  = 0;

   switch(color) {
      case RED:
         *red = 255;
         break;
      case ORANGE:
         *red   = 255;
         *green = 165;
         break;
      case YELLOW:
         *red   = 255;
         *green = 255;
         break;
      case GREEN:
         *green = 255;
         break;
      case BLUE:
         *blue = 255;
         break;
      case PURPLE:
         *red  = 128;
         *blue = 128;
         break;
   }
}


uint32_t create_color(unsigned char red, unsigned char green, unsigned char blue) {
   // Create a 24 bit color value from R, G, B values
   uint32_t color;

   color = red;
   color <<= 8;

   color |= green;
   color <<= 8;
   
   color |= blue;

   return color;
}


void get_start_and_end_pixels(int direction, int *start_pixel, int *end_pixel) {
   switch(direction) {
      case UP:
         *start_pixel = lights.numPixels();
         *end_pixel = 0;
         break;
      case DOWN:
         *start_pixel = 0;
         *end_pixel = lights.numPixels();
         break;
   }
}


uint32_t color_wheel(unsigned char wheel_position) {
   // Input a value 0 to 255 to get a color value.
   // The colours are a transition r - g -b - back to r

   if(wheel_position < 85) {
      return create_color(wheel_position*3, 255 - wheel_position*3, 0);
   } else if(wheel_position < 170) {
      wheel_position -= 85;
      return create_color(255 - wheel_position*3, 0, wheel_position*3);
   } else {
      wheel_position -= 170; 
      return create_color(0, wheel_position*3, 255 - wheel_position*3);
   }
}


void enableIrTransmitters(int khz) {
   // Disable the timer 2 Interrupt (which is used for receiving IR)
   TIMER_DISABLE_INTR;
  
   pinMode(TIMER_PWM_PIN, OUTPUT);

   // When not sending PWM, we want it low
   digitalWrite(TIMER_PWM_PIN, LOW);
  
   // The modulation frequency is F_CPU / 2 / OCR2A (output compare register 2A)
   const uint8_t pwm_val = F_CPU / 2000 / IR_KHZ;

   TCCR2A = _BV(WGM20);
   TCCR2B = _BV(WGM22) | _BV(CS20);
   OCR2A  = pwm_val;
   OCR2B  = pwm_val / 3;

   // Enable PWM output on pin 3
   TIMER_ENABLE_PWM;
}