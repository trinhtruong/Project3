#include "IO_config.h"
#include "sensor.h"
#include "fifo.h"
#include <Wire.h>

// serial stuff  
static const byte LF = 10; // line feed character

static const unsigned long _BAUDRATE = 115200;
HardwareSerial *serialPtr = &Serial;

uint8_t rcvbuf[16], rcvbufpos = 0, c;

// fps calculation stuff
static unsigned int oneSecond = 1000;
unsigned int volatile frameCount = 0;
unsigned int fps = 0;
unsigned long volatile lastTime = 0;
unsigned long volatile timeStamp = 0;

static const uint8_t fW = 160;
static const uint8_t fH = 120;

static const uint8_t TRACK_BORDER = 4; // always multiple of 2 (YUYV: 2 pixels)
static const uint8_t YUYV_BPP = 2; // bytes per pixel
static const unsigned int MAX_FRAME_LEN = fW * YUYV_BPP;

byte rowBuf[MAX_FRAME_LEN];

unsigned int volatile nRowsSent = 0;
boolean volatile bRequestPending = false;
boolean volatile bNewFrame = false;
uint8_t volatile thresh = 128;

enum serialRequest_t {
  SEND_NONE = 0,
  SEND_DARK,
  SEND_BRIG,
  SEND_FPS,
  SEND_0PPB = MAX_FRAME_LEN,
  SEND_1PPB = fW,
  SEND_2PPB = fW/2,
  SEND_4PPB = fW/4,
  SEND_8PPB =fW/8 
};

serialRequest_t serialRequest = SEND_0PPB;

// *****************************************************
//                          SETUP
// *****************************************************
void setup()
{
  setup_IO_ports();
  
  serialPtr->begin(_BAUDRATE);

  serialPtr->println("Initializing sensor...");
  for (int i = 0; i < 10; i ++) {
       unsigned int result = sensor_init();
      if (result != 0) {
        //serialPtr->print("inited OK, sensor PID: ");
        //serialPtr->println(result, HEX);
        break;
      }
      else if (i == 5) {
          serialPtr->println("PANIC! sensor init keeps failing!");
          while (1);
      } else {
          serialPtr->println("retrying...");
          delay(300);
      }
  }
  DISABLE_WREN; // disable writing to fifo
  attachInterrupt(VSYNC_INT, &vsyncIntFunc, FALLING);
  delay(100);
}
// *****************************************************
//                          LOOP
// *****************************************************
void loop()
{  
 

}

// *****************************************************
//               VSYNC INTERRUPT HANDLER
// *****************************************************
void __inline__ vsyncIntFunc() {
      DISABLE_WREN; // disable writing to fifo
          
      if (bNewFrame) {
		DISABLE_WREN; // disable writing to fif
        detachInterrupt(VSYNC_INT);
        processRequest();
        bNewFrame = 0;
        attachInterrupt(VSYNC_INT, &vsyncIntFunc, FALLING);
      }
      else {
          ENABLE_WRST;
          //__delay_cycles(500);
          SET_RCLK_H;
          //__delay_cycles(100);
          SET_RCLK_L;
          DISABLE_WRST;
                   
          ENABLE_WREN; // enable writing to fifo
          bNewFrame = 1;
      }
}

// **************************************************************
//                      PROCESS SERIAL REQUEST
// **************************************************************
void processRequest() {
		//fifo rrst
		ENABLE_RRST;
		//_delayNanoseconds(5);
		SET_RCLK_H;
		//_delayNanoseconds(5);
		SET_RCLK_L;
		DISABLE_RRST;
	  	
        switch (serialRequest) {
          case SEND_0PPB: for (int i =0; i< fH; i++) {
                              fifo_readRow0ppb(rowBuf, rowBuf + serialRequest);
                              serialPtr->write(rowBuf, serialRequest);
                              serialPtr->write(LF);
							  //serialPtr->print("\n");
							  } break;
          case SEND_1PPB: for (int i =0; i< fH; i++) {
                              fifo_readRow1ppb(rowBuf, rowBuf + serialRequest);
                              serialPtr->write(rowBuf, serialRequest); 
                              serialPtr->write(LF); 
                          } break;
          case SEND_2PPB:  for (int i =0; i< fH; i++) {
                              fifo_readRow2ppb(rowBuf, rowBuf + serialRequest);
                              serialPtr->write(rowBuf, serialRequest); 
                              serialPtr->write(LF); 
                          } break;
          case SEND_4PPB: for (int i =0; i< fH; i++) {
                              fifo_readRow4ppb(rowBuf, rowBuf + serialRequest);
                              serialPtr->write(rowBuf, serialRequest); 
                              serialPtr->write(LF); 
                          } break;
          case SEND_8PPB: for (int i =0; i< fH; i++) {
                              fifo_readRow8ppb(rowBuf, rowBuf + serialRequest, thresh);
                              serialPtr->write(rowBuf, serialRequest); 
                              serialPtr->write(LF); 
                          } break;
          case SEND_BRIG: fifo_getBrig(rowBuf, fW, fH, TRACK_BORDER, thresh);
                          serialPtr->write(rowBuf, 4);
                          serialPtr->write(LF); 
                          break;
          case SEND_DARK: fifo_getDark(rowBuf, fW, fH, TRACK_BORDER, thresh);
                          serialPtr->write(rowBuf, 4);
                          serialPtr->write(LF); 
                          break;
          case SEND_FPS:  calcFPS(fps);
                          serialPtr->print(fps, DEC);
                          serialPtr->write(LF); 
                          break;
          default : break;
        }
}

void fifo_readRow0ppb(uint8_t* _rowStart, uint8_t* _rowEnd)
{
    while (_rowStart != _rowEnd) {
      SET_RCLK_H;
      *_rowStart++ = DATA_PINS;
	  //Serial.print("Data_pins");
	  //serialPtr->print(DATA_PINS, DEC);
	  //serialPtr->print("\t");
	  //Serial.println(DATA_PINS, HEX);
     // _delayNanoseconds(5);
      SET_RCLK_L;
      //_delayNanoseconds(5);
    }
}

// **************************************************************
//                      CALCULATE FPS
// **************************************************************
void calcFPS(unsigned int &currentFPS) {
      unsigned long currTime = millis();
      unsigned long currTimeDiff = currTime-lastTime;
      if (currTimeDiff >= oneSecond) {
        lastTime = currTime;
        currentFPS = (oneSecond*frameCount)/currTimeDiff;
       frameCount = 0;
       
      }
      while (GET_VSYNC); // wait for an old frame to end
      while (!GET_VSYNC);// wait for a new frame to start
      frameCount++;
}
// **************************************************************
//                      SERIAL EVENT
// **************************************************************

void serialEvent() {
  while (serialPtr->available()) {
    // get the new byte:
    c = serialPtr->read();
    if (c != LF) {
            rcvbuf[rcvbufpos++] = c;
    } else if (c == LF) {
        rcvbuf[rcvbufpos++] = 0;
        rcvbufpos = 0;
        parseSerialBuffer();
    }
  }
}

// *****************************************************
//               PARSE SERIAL BUFFER
// ****************************************************
void parseSerialBuffer(void) {
       if (strcmp((char *) rcvbuf, "hello") == 0) {
            serialPtr->print("Hello to you too!\n");
        } else if ( strlen((char *) rcvbuf) > 5 && 
                    strncmp((char *) rcvbuf, "send ", 5) == 0) {
            serialRequest = (serialRequest_t)atoi((char *) (rcvbuf + 5)); 
            serialPtr->print("ACK\n");
            bRequestPending = true;       
        } 
        else if (strlen((char *) rcvbuf) > 5 &&
                strncmp((char *) rcvbuf, "dark ", 5) == 0) {
                  thresh = atoi((char *) (rcvbuf + 5));
                  serialPtr->print("ACK\n");
                  serialRequest = SEND_DARK;
                  bRequestPending = true;
        }
        else if (strlen((char *) rcvbuf) > 5 &&
                strncmp((char *) rcvbuf, "brig ", 5) == 0) {
                  thresh = atoi((char *) (rcvbuf + 5));
                  serialPtr->print("ACK\n");
                  serialRequest = SEND_BRIG;
                  bRequestPending = true;
        }
        else if (strlen((char *) rcvbuf) > 7 &&
                strncmp((char *) rcvbuf, "thresh ", 7) == 0) {
                  thresh = atoi((char *) (rcvbuf + 7));
        }
}

