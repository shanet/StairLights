// StairLights
// shane tully (shane@shanetully.com)
// shanetully.com

// GitHub repo: https://github.com/shanet/StairLights
// Makes use of the Adafruit WS2801 LED library
// https://github.com/adafruit/Adafruit-WS2801-Library
// Code snippits taken from the Arduino IRremote library
// https://github.com/shirriff/Arduino-IRremote

// Copyright (C) 2013 Shane Tully

//This program is free software: you can redistribute it and/or modify
//it under the terms of the GNU Lesser General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.

// You should have received a copy of the GNU Lesser General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include "SPI.h"
#include "Adafruit_WS2801.h"

#define IR_DETECT_UPSTAIRS_PIN     2
#define IR_DETECT_DOWNSTAIRS_PIN   4

#define LIGHTS_DATA_PIN  6 // Yellow wire
#define LIGHTS_CLOCK_PIN 7 // Green wire

// IR transmit frequency. You probably don't want to change this.
#define IR_KHZ     38

// Number of pixels (LEDs) in the strand
#define NUM_PIXELS 20

// Color options
#define MULTI  0
#define RED    1
#define ORANGE 2
#define YELLOW 3
#define GREEN  4
#define BLUE   5
#define PURPLE 6

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

// Direction of the light pattern
#define UP   0
#define DOWN 1

#define FADE_INCOMPLETE 0
#define FADE_COMPLETE   1

// Macros for the IR transmitters. See the enable IR transmitters function.
#define TIMER_PWM_PIN        3
#define TIMER_ENABLE_PWM     (TCCR2A |= _BV(COM2B1))
#define TIMER_DISABLE_INTR   (TIMSK2 = 0)

Adafruit_WS2801 lights = Adafruit_WS2801((uint16_t)NUM_PIXELS, (uint8_t)LIGHTS_DATA_PIN, (uint8_t)LIGHTS_CLOCK_PIN, (uint8_t)WS2801_GRB);

void setup() {
   pinMode(IR_DETECT_UPSTAIRS_PIN, INPUT);
   pinMode(IR_DETECT_DOWNSTAIRS_PIN, INPUT);

   enableIrTransmitters(IR_KHZ);

   lights.begin();

   randomSeed(analogRead(0));

   // Wait a second to prevent "phantom" signals from the IR receivers on start up
   delay(1000);
}

void loop() {
   if(!digitalRead(IR_DETECT_UPSTAIRS_PIN)) {
      show_stair_lights(DOWN);
   } else if(!digitalRead(IR_DETECT_DOWNSTAIRS_PIN)) {
      show_stair_lights(UP);
   }
}


void show_stair_lights(int direction) {
   // Pick a random light pattern
   int pattern = random(0, 6);

   switch(pattern) {
      case 0:
         basic_color(direction);
         break;
      case 1:
         rainbow(direction, 75);
         break;
      case 2:
         rainbow_cycle(direction, 4, 20);
         break;
      case 3:
         colorswirl(direction, 10000);
         break;
      case 4:
         trail(direction, 7, 10, 50);
         break;
      case 5:
         stack(direction, 50);
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
   run_colors(0, red, 0, green, 0, blue, steps, direction, delay_time);

   delay(10000);

   // Fade out more slowly
   steps      = 100;
   delay_time = 40;
   run_colors(red, 0, green, 0, blue, 0, steps, direction, delay_time);
}


void run_colors(unsigned char old_red, unsigned char new_red, unsigned char old_green, unsigned char new_green, 
               unsigned char old_blue, unsigned char new_blue, int steps, int direction, int delay_time) {
   int start_pixel;
   int end_pixel;
   get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

   float red_step   = (float)(new_red   - old_red)   / steps;
   float green_step = (float)(new_green - old_green) / steps;
   float blue_step  = (float)(new_blue  - old_blue)  / steps;

   if(direction == UP) start_pixel++;

   for(int i=start_pixel; (direction == UP ? i>=end_pixel : i<end_pixel); (direction == DOWN ? i+=2 : i-=2)) {
      float cur_red   = old_red;
      float cur_green = old_green;
      float cur_blue  = old_blue;

      for(int j=0; j<steps; j++) {
         cur_red   += red_step;
         cur_green += green_step;
         cur_blue  += blue_step;

         lights.setPixelColor(i, (unsigned char)cur_red, (unsigned char)cur_green, (unsigned char)cur_blue);
         lights.setPixelColor(i+1, (unsigned char)cur_red, (unsigned char)cur_green, (unsigned char)cur_blue);
         lights.show();

         delay(6);
      }

      delay(delay_time);
   }
}


void fade_colors(unsigned char old_red, unsigned char new_red, unsigned char old_green, unsigned char new_green, 
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


void rainbow(int direction, int delay_time) {
   float fade_constant = 0;
   int shadow_position = get_initial_shadow_position(direction);

   int start_pixel;
   int end_pixel;
   get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

   // 3 cycles of all 256 colors in the color_wheel
   for(int i=0; i<256; i++) {
      // Fade in and out on the first and last 50 cycles
      if(i < 50) {
         fade_constant += .02;
      } else if(i > 205) {
         fade_constant -= .02;
      }

      // Show the pixels one by one up/down the stairs during fading
      if(i < lights.numPixels()) {
         if(direction == UP) {
            shadow_position--;
         } else {
            shadow_position++;
         }
      }

      for(int j=start_pixel; (direction == UP ? j>=end_pixel : j<end_pixel); (direction == DOWN ? j++ : j--)) {
         float local_fade_constant = fade_constant;
         if(i < lights.numPixels() && (direction == DOWN ? j > shadow_position : j < shadow_position)) {
            local_fade_constant = 0;
         }

         lights.setPixelColor(j, color_wheel((i + j) % 255, local_fade_constant));
      }  

      lights.show();

      delay(delay_time);
   }
}


void rainbow_cycle(int direction, int num_cycles, int delay_time) {
   float fade_constant = 0;
   int shadow_position = get_initial_shadow_position(direction);

   int start_pixel;
   int end_pixel;
   get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

   for(int i=0; i<256*num_cycles; i++) {
      // Fade in and out on the first and last 50 cycles
      if(i < 50) {
         fade_constant += .02;
      } else if(i > 256*num_cycles - 51) {
         fade_constant -= .02;
      }

      // Show the pixels one by one up/down the stairs during fading
      if(i < lights.numPixels()) {
         if(direction == UP) {
            shadow_position--;
         } else {
            shadow_position++;
         }
      }

      for(int j=0; j<lights.numPixels(); j++) {
         // we use each pixel as a fraction of the full 96-color color_wheel
         // (thats the i / lights.numPixels() part)
         // Then add in j which makes the colors go around per pixel
         // the % 96 is to make the color_wheel cycle around
         float local_fade_constant = fade_constant;
         if(i < lights.numPixels() && (direction == DOWN ? j > shadow_position : j < shadow_position)) {
            local_fade_constant = 0;
         }

         uint32_t color = color_wheel(((j * 256 / lights.numPixels()) + i) % 256, local_fade_constant);
         lights.setPixelColor(j, color);
      }

      lights.show();

      if(i < lights.numPixels()) {
         delay(delay_time*4);
      } else {
         delay(delay_time);
      }
   }
}


void trail(int direction, int trail_len, int cycles, int delay_time) {
   unsigned char red   = 0;
   unsigned char green = 0;
   unsigned char blue  = 0;
   get_random_color(&red, &green, &blue);

   int start_pixel;
   int end_pixel;
   get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

   // Generate the constants to multiply the brightness by for the trail
   float trail_constants[trail_len];
   trail_constants[0] = (float)1/trail_len;
   for(int i=2; i<=trail_len; i++) {
      trail_constants[i-1] = trail_constants[i-2] + (float)1/trail_len;
   }

   for(int i=0; i<cycles; i++) {
      // Pick a new random color on each cycle
      unsigned char red;
      unsigned char green;
      unsigned char blue;
      get_random_color(&red, &green, &blue);

      for(int j=start_pixel; (direction == UP ? j>=end_pixel-trail_len : j<=end_pixel+trail_len); (direction == DOWN ? j++ : j--)) {
         // Set all non-trail pixels to 0
         for(int k=0; k<lights.numPixels(); k++) {
            lights.setPixelColor(k, 0, 0, 0);
         }

         // Set the trail pixels to the appropriate color
         int k = j-trail_len;
         if(direction == UP) {
            k = j+trail_len;
         }
         for(int l=0; (direction == UP ? k>j-trail_len : k<j+trail_len); (direction == UP ? k-- : k++), l++) {
            lights.setPixelColor(k, red*trail_constants[l], green*trail_constants[l], blue*trail_constants[l]);
         }

         lights.show();

         delay(delay_time);
      }
   }

   clear_lights();
}


void stack(int direction, int delay_time) {
   uint32_t color = get_random_color();

   show_stack(direction, color, delay_time);

   delay(10000);

   show_destack(direction, color, delay_time);

   clear_lights();
}


void show_stack(int direction, uint32_t color, int delay_time) {
   // The start and end pixels are reversed from the other patterns so don't use
   // the get start and end pixels function
   int start_pixel;
   int end_pixel;
   int target;
   switch(direction) {
      case UP:
         start_pixel = 0;
         end_pixel   = lights.numPixels();
         target      = lights.numPixels() - 1;
         break;
      case DOWN:
         start_pixel = lights.numPixels() - 1;
         end_pixel   = 0;
         target      = 0;
         break;
   }

   for(int i=start_pixel; (direction == UP ? i<end_pixel : i>end_pixel); (direction == DOWN ? i-=2 : i+=2)) {
      int cur_stair = lights.numPixels() - 1;
      if(direction == UP) {
         cur_stair = 0;
      }
   
      while((direction == UP ? cur_stair < target : cur_stair > target)) {
         // Turn off all pixels below the target level
         for(int j=start_pixel; (direction == UP ? j<target : j>target); (direction == DOWN ? j-- : j++)) {
            lights.setPixelColor(j, 0);
         }

         // Set the current pixel and the next pixel to the given color
         lights.setPixelColor(cur_stair, color);
         if(direction == UP) {
            lights.setPixelColor(cur_stair+1, color);
         } else {
            lights.setPixelColor(cur_stair-1, color);
         }
         lights.show();
         
         if(direction == UP) {
            cur_stair += 2;
         } else {
            cur_stair -= 2;
         }

         delay(delay_time);
      }

      if(direction == UP) {
         target -= 2;
      } else {
         target += 2;
      }
   }
}


void show_destack(int direction, uint32_t color, int delay_time) {
   int start_pixel;
   int end_pixel;
   get_start_and_end_pixels(direction, &start_pixel, &end_pixel);

   int target = lights.numPixels()-1;
   if(direction == UP) {
      target = 0;
   }

   for(int i=start_pixel; (direction == UP ? i>end_pixel : i<end_pixel); (direction == DOWN ? i+=2 : i-=2)) {
      int cur_stair = target;
   
      while((direction == UP ? cur_stair >= end_pixel : cur_stair <= end_pixel)) {
         // Turn off all pixels above the target level
         for(int j=end_pixel; (direction == UP ? j<target+2 : j>target-2); (direction == DOWN ? j-- : j++)) {
            lights.setPixelColor(j, 0);
         }

         // Set the current pixel and the next pixel to the given color
         lights.setPixelColor(cur_stair, color);
         if(direction == UP) {
            lights.setPixelColor(cur_stair+1, color);
         } else {
            lights.setPixelColor(cur_stair-1, color);
         }
         lights.show();
         
         if(direction == UP) {
            cur_stair -= 2;
         } else {
            cur_stair += 2;
         }

         delay(delay_time);
      }

      if(direction == UP) {
         target += 2;
      } else {
         target -= 2;
      }
   }
}


void colorswirl(int direction, int run_time) {
   // These are fun to play with to generate different effects
   // See the macros defined at the top of the file for options
   int color           = MULTI;
   int rotation_speed  = ROT_VERY_FAST;
   int rotation_dir    = ROT_CCW;
   int shadow_length   = SDW_VERY_SMALL;
   int fade_speed      = FADE_NONE;

   // Rotate the other way if going down the stairs
   if(direction == DOWN) {
      rotation_dir = ROT_CW;
   }

   unsigned long start_time = millis();

   // Fade in
   while(get_colorswirl_data(1, 0, color, rotation_speed, rotation_dir, shadow_length, fade_speed) != FADE_COMPLETE) {
      lights.show();
   }

   // Main loop
   // Run for the specified time
   while(start_time + run_time > millis()) {
      get_colorswirl_data(0, 0, color, rotation_speed, rotation_dir, shadow_length, fade_speed);
      lights.show();
   }

   // Fade out
   while(get_colorswirl_data(0, 1, color, rotation_speed, rotation_dir, shadow_length, fade_speed) != FADE_COMPLETE) {
      lights.show();
   }
}


int get_colorswirl_data(int fade_in, int fade_out, int color, int rotation_speed, int rotation_dir, int shadow_length, int fade_speed) {
   static float shadow_position = 0;
   static float light_position  = 0;
   static int hue               = 0;
   static float fade_constant   = 0;

   int brightness;
   unsigned char red;
   unsigned char green;
   unsigned char blue;

   shadow_position = light_position;

   for(int i=0; i<lights.numPixels(); i++) {
      get_led_color(color, &red, &green, &blue, hue);

      // Resulting hue is multiplied by brightness in the
      // range of 0 to 255 (0 = off, 255 = brightest).
      // Gamma corrrection (the 'pow' function here) adjusts
      // the brightness to be more perceptually linear.
      brightness = (shadow_length != SDW_NONE || rotation_speed != ROT_NONE) ? (int)(pow(0.5 + sin(shadow_position) * 0.5, 3.0) * 255.0) : 255;

      // If fading in or out, reduce the brightness by the fade constant
      if(fade_in || fade_out) {
         brightness *= fade_constant;
      }

      lights.setPixelColor(i, create_color((red*brightness) / 255, (green*brightness) / 255, (blue*brightness) / 255));

      // Each pixel is offset in both hue and brightness
      update_shadow_position(shadow_length, &shadow_position);
   }

   // If color is multi and fade flag was selected, do a slow fade between colors with the rot speed
   if(fade_speed != FADE_NONE && color == MULTI) {
      switch(fade_speed) {
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
   update_hue(&hue);
   update_light_position(rotation_speed, rotation_dir, &light_position);

   return update_fade_constant(fade_in, fade_out, &fade_constant);
}


void get_led_color(int color, unsigned char *r, unsigned char *g, unsigned char *b, int cur_hue) {
    unsigned char low_byte;

    switch(color) {
        case MULTI:
            // Fixed-point hue-to-RGB conversion.  'cur_hue' is an
            // integer in the range of 0 to 1535, where 0 = red,
            // 256 = yellow, 512 = green, etc.  The high byte
            // (0-5) corresponds to the sextant within the color
            // wheel, while the low byte (0-255) is the
            // fractional part between primary/secondary colors.
            low_byte = cur_hue & 255;

            switch((cur_hue >> 8) % 6) {
                case 0:
                    *r = 255;
                    *g = low_byte;
                    *b = 0;
                    break;
                case 1:
                    *r = 255 - low_byte;
                    *g = 255;
                    *b = 0;
                    break;
                case 2:
                    *r = 0;
                    *g = 255;
                    *b = low_byte;
                    break;
                case 3:
                    *r = 0;
                    *g = 255 - low_byte;
                    *b = 255;
                    break;
                case 4:
                    *r = low_byte;
                    *g = 0;
                    *b = 255;
                    break;
                case 5:
                    *r = 255;
                    *g = 0;
                    *b = 255 - low_byte;
                    break;
            }

            cur_hue += 40;
            break;
        case RED:
            *r = 255;
            *g = 0;
            *b = 0;
            break;
        case ORANGE:
            *r = 255;
            *g = 165;
            *b = 0;
            break;
        case YELLOW:
            *r = 255;
            *g = 255;
            *b = 0;
            break;
        case GREEN:
            *r = 0;
            *g = 255;
            *b = 0;
            break;
        case BLUE:
            *r = 0;
            *g = 0;
            *b = 255;
            break;
        case PURPLE:
            *r = 128;
            *g = 0;
            *b = 128;
            break;
    }
}


void update_light_position(int rotation_speed, int rotation_dir, float *light_position) {
    switch(rotation_speed) {
        case ROT_NONE:
            *light_position = 0;
            break;
        case ROT_VERY_SLOW:
            *light_position += (rotation_dir == ROT_CW) ? -.007 : .007;
            break;
        case ROT_SLOW:
            *light_position += (rotation_dir == ROT_CW) ? -.015 : .015;
            break;
        case ROT_NORMAL:
        default:
            *light_position += (rotation_dir == ROT_CW) ? -.03 : .03;
            break;
        case ROT_FAST:
            *light_position += (rotation_dir == ROT_CW) ? -.045 : .045;
            break;
        case ROT_VERY_FAST:
            *light_position += (rotation_dir == ROT_CW) ? -.07 : .07;
            break;
    }
}


void update_shadow_position(int shadow_length, float *shadow_position) {
    switch(shadow_length) {
        case SDW_NONE:
            *shadow_position += 0;
            break;
        case SDW_VERY_SMALL:
            *shadow_position += 0.9;
            break;
        case SDW_SMALL:
            *shadow_position += 0.6;
            break;
        case SDW_NORMAL:
        default:
            *shadow_position += 0.3;
            break;
        case SDW_LONG:
            *shadow_position += 0.2;
            break;
        case SDW_VERY_LONG:
            *shadow_position += 0.08;
            break;
    }
}


void update_hue(int *cur_hue) {
    static int hue = 0;
    *cur_hue = hue = (hue + 5) % 1536;
}


int update_fade_constant(int fade_in, int fade_out, float *fade_constant) {
   #define FADE_STEP .0025;

   // If fading in, add the fade step to the fade constant
   // If the constant is 1, we're finished fading in
   if(fade_in && *fade_constant < 1) {
      *fade_constant += FADE_STEP;

      if(*fade_constant >= 1) {
         return FADE_COMPLETE;
      }
   // If fading out, subtract the fade step to the fade constant
   // If the constant is 0, we're finished fading out
   } else if(fade_out && *fade_constant > 0) {
      *fade_constant -= FADE_STEP;

      if(*fade_constant <= 0) {
         return FADE_COMPLETE;
      }
   } else {
      return FADE_INCOMPLETE;
   }
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


uint32_t get_random_color(void) {
   unsigned char red   = 0;
   unsigned char green = 0;
   unsigned char blue  = 0;

   get_random_color(&red, &green, &blue);
   return create_color(red, green, blue);
}


void clear_lights(void) {
   // Turn off all lights
   for(int i=0; i<lights.numPixels(); i++) {
      lights.setPixelColor(i, 0);
      lights.show();
   }
}


uint32_t create_color(unsigned char red, unsigned char green, unsigned char blue) {
   // Create a 24 bit color value from R, G, B values
   // Bits 24-16: red
   // Bits 15-8:  green
   // Bits 7-0:   blue
   uint32_t color;

   color = red;
   color <<= 8;

   color |= green;
   color <<= 8;
   
   color |= blue;

   return color;
}


int get_initial_shadow_position(int direction) {
   // For fades with a shadow, the shadow should grow from the beginning or end
   // of the LEDs depending on direction
   switch(direction) {
      case UP:
         return lights.numPixels();
      case DOWN:
         return 0;
   }
}


void get_start_and_end_pixels(int direction, int *start_pixel, int *end_pixel) {
   switch(direction) {
      case UP:
         *start_pixel = lights.numPixels() - 1;
         *end_pixel = 0;
         break;
      case DOWN:
         *start_pixel = 0;
         *end_pixel = lights.numPixels() - 1;
         break;
   }
}


uint32_t color_wheel(unsigned char wheel_position, float fade_constant) {
   // Input a value 0 to 255 to get a color value.
   // The colours are a transition r - g -b - back to r
   if(wheel_position < 85) {
      return create_color(fade_constant * wheel_position*3, fade_constant * (255 - wheel_position*3), 0);
   } else if(wheel_position < 170) {
      wheel_position -= 85;
      return create_color(fade_constant * (255 - wheel_position*3), 0, fade_constant * wheel_position*3);
   } else {
      wheel_position -= 170; 
      return create_color(0, fade_constant * wheel_position*3, fade_constant * (255 - wheel_position*3));
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