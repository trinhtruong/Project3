#ifndef IO_CONFIG_H_
#define IO_CONFIG_H_

#include <avr/io.h>


// data pins --------------------

#define DATA_DDR	    DDRD
#define DATA_PORT	    PORTD
#define DATA_PINS	    (PINC&15)|(PIND&240) //(PINC&7)|(PIND&248)

// control pins --------------------
#define VSYNC_INT 0 

#ifdef VSYNC_INT
  #define OV_VSYNC            _BV(PIND2) 
#else
  #define OV_VSYNC            _BV(PINB0) 
#endif

#define FIFO_WREN          _BV(PINB0)          // Write Enable (active low) 
#define FIFO_RCLK          _BV(PINB1)          // Read clock
#define FIFO_WRST          _BV(PINB4)          // Write Reset (active low)
#define FIFO_RRST          _BV(PINB5)          // Read Reset (active low)

#define WREN_DDR          DDRB
#define WREN_PORT         PORTB

#define RCLK_DDR          DDRB
#define RCLK_PORT         PORTB

#define WRST_DDR          DDRB
#define WRST_PORT         PORTB

#define RRST_DDR          DDRB
#define RRST_PORT         PORTB

#ifdef VSYNC_INT
  #define VSYNC_PIN         PIND
  #define VSYNC_DDR         DDRD
  #define VSYNC_PORT        PORTD
#else
  #define VSYNC_PIN         PINB
  #define VSYNC_DDR         DDRB
  #define VSYNC_PORT        PORTB
#endif

#define GET_VSYNC          (VSYNC_PIN & OV_VSYNC) 

#define DISABLE_RRST        RRST_PORT|=FIFO_RRST
#define ENABLE_RRST          RRST_PORT&=~FIFO_RRST 

#define DISABLE_WRST        WRST_PORT|=FIFO_WRST
#define ENABLE_WRST          WRST_PORT&=~FIFO_WRST 

#define SET_RCLK_H            RCLK_PORT|=FIFO_RCLK   
#define SET_RCLK_L          RCLK_PORT&=~FIFO_RCLK

#define ENABLE_WREN         WREN_PORT |= FIFO_WREN
#define DISABLE_WREN         WREN_PORT &= ~FIFO_WREN


// *************************************
void static inline setup_IO_ports() {
  //pinMode(14, INPUT);
  //pinMode(15, INPUT);
  //pinMode(16, INPUT);
  //pinMode(17, INPUT);
  
  DDRC &= ~15;
  
  // reset registers and register directions
  DDRB = DDRD = PORTB = PORTD = 0;
  // set fifo data pins as inputs 
  DATA_DDR  = 0;  // set pins as INPUTS
  
  WREN_DDR  |= FIFO_WREN; // set pin as OUTPUT
  RCLK_DDR  |= FIFO_RCLK; // set pin as OUTPUT
  RRST_DDR  |= FIFO_RRST; // set pin as OUTPUT
  WRST_DDR  |= FIFO_WRST; // set pin as OUTPUT
  
  VSYNC_DDR &= ~(OV_VSYNC); // set pin as INPUT
#ifdef VSYNC_INT
  VSYNC_PORT |= OV_VSYNC; // enable pullup (for interruption handler)
#endif
}


#endif /* IO_CONFIG_H_ */
