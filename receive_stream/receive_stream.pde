import processing.serial.*;
import java.util.*;

Serial serialPort;     

request_t       request;
requestStatus_t reqStatus = requestStatus_t.IDLE;

// incoming serial 
byte [] xX = new byte[G_DEF.F_H*G_DEF.F_W];
byte[]   ackBuff = new byte[G_DEF.ACK_BUF_LEN];
byte[][] pix     = new byte[G_DEF.F_H][G_DEF.MAX_ROW_LEN];
byte [] save_data = new byte[G_DEF.F_H*G_DEF.MAX_ROW_LEN];

double waitTimeout    = 0;
double fpsTimeStamp   = 0;

PFont  myFont;
PImage currFrame;

boolean bSerialDebug = true;

int currRow = 0;
byte thresh  = (byte)130;

PVector lastCenter = new PVector(0,0);
float tmp_x0 = 0, tmp_y0 = 0, tmp_x1 = 0, tmp_y1 = 0;
float x0 = 0, y0 = 0, x1 = 0, y1 = 0;

boolean bKalmanEnabled = true;
simpleKalman filter_x0 = new simpleKalman();
simpleKalman filter_y0 = new simpleKalman();
simpleKalman filter_x1 = new simpleKalman();
simpleKalman filter_y1 = new simpleKalman();
  
// ************************************************************
//                          SETUP
// ************************************************************
 
void setup() {
  size(640, 507);
  frameRate(30);
  
  currFrame = createImage(G_DEF.F_W, G_DEF.F_H, RGB);
  
  
  // create a font with the third font available to the system:
  //myFont = createFont("Arial", G_DEF.FONT_SIZE);
  //textFont(myFont);

  // List all the available serial serialPorts:
  printArray(Serial.list());

  delay(500);
  serialPort = new Serial(this, "COM5", G_DEF.BAUDRATE);
  serialPort.bufferUntil(G_DEF.LF);
  serialPort.clear();
  delay(2000);
  reqStatus = reqStatus.IDLE;
  request = request.STREAM0PPB;
}
  
// ************************************************************
//                          DRAW
// ************************************************************
void draw() {
	switch (reqStatus) {
        case RECEIVED:  reqStatus = requestStatus_t.PROCESSING;
                                            buff2pixFrame(pix, currFrame, request);
                                            noSmooth();
                                            image(currFrame,0,0, G_DEF.F_W*G_DEF.DRAW_SCALE,G_DEF.F_H*G_DEF.DRAW_SCALE);
                                            smooth();
                                            drawFPS();
                                            reqStatus = requestStatus_t.IDLE;
                                            break;
        case TIMEOUT:   
        case IDLE:      reqImage(request);
                                            reqStatus = requestStatus_t.REQUESTED; 
                                            waitTimeout = G_DEF.SERIAL_TIMEOUT + millis();
                                            break;
        case REQUESTED:  if (millis() > waitTimeout) reqStatus = requestStatus_t.TIMEOUT;
                                            break;
        case ARRIVING:  break;
        case PROCESSING:  break;
        default : break;
    }                                       
}

// ************************************************************
//                     SERIAL EVENT HANDLER
// ************************************************************
void serialEvent(Serial serialPort) {

    if (reqStatus == requestStatus_t.REQUESTED) {
          int numBytesRead = serialPort.readBytesUntil(G_DEF.LF, ackBuff);
          if ((numBytesRead >= 4) && 
              (ackBuff[numBytesRead-4] == 'A') &&
              (ackBuff[numBytesRead-3] == 'C') &&
              (ackBuff[numBytesRead-2] == 'K') ) {
            reqStatus = requestStatus_t.ARRIVING;
          } else if (millis() > waitTimeout) {
            reqStatus = requestStatus_t.TIMEOUT;
          }
    }
    else if (reqStatus == requestStatus_t.ARRIVING) {
        parseSerialData();
    }
    else {
      if (bSerialDebug) print(serialPort.readStringUntil(G_DEF.LF)); 
    }
}

// ************************************************************
//                       PARSE SERIAL DATA
// ************************************************************
void parseSerialData() {
	serialPort.readBytes(pix[currRow]);
	serialPort.clear();
	currRow++;
	if (currRow >= G_DEF.F_H) {
		reqStatus = requestStatus_t.RECEIVED; // frame ready on buffer
		currRow = 0;
		if (bSerialDebug) println();
	}
}      

  
// ************************************************************
//                      REQUEST IMAGE
// ************************************************************
void reqImage(request_t req) {
      currRow = 0;
      serialPort.clear();
      serialPort.write("thresh "+Integer.toString(int(thresh))+G_DEF.LF);
      serialPort.write("send "+Integer.toString(req.getParam())+G_DEF.LF);
}
  
// ************************************************************
//                  REQUEST TRACKING DATA
// ************************************************************
void reqTracking(request_t req) {
    
      serialPort.clear();
      if (req == request_t.TRACKDARK)
          serialPort.write("dark "+Integer.toString(int(thresh))+G_DEF.LF);
      else if (req == request_t.TRACKBRIG)
          serialPort.write("brig "+Integer.toString(int(thresh))+G_DEF.LF);
       
}

// ************************************************************
//                           DRAW FPS
// ************************************************************
void drawFPS() {
   long currTime = millis();
   float fps =1000.0/(float)(currTime-fpsTimeStamp);
   
   pushStyle();
   pushMatrix();
   noStroke();
   fill(0);
   rect(20, 20, textWidth("FPS: "+fps), G_DEF.FONT_SIZE);
   fill(255);
   translate(0,-2);
   textAlign(LEFT, TOP);
   text("FPS: "+fps, 20, 20);
   popMatrix();
   popStyle();
   fpsTimeStamp = currTime;
}
  
// ************************************************************
//                      DRAW TRACKING
// ************************************************************
void drawTracking() {
   pushStyle();
   noFill(); 
   strokeWeight(3);
   
   if (tmp_x1-tmp_x0 > 3 && tmp_x1-tmp_x0 < G_DEF.F_W/2 && tmp_y1-tmp_y0 < G_DEF.F_H/2 && tmp_y1-tmp_y0 > 3) {
		 stroke(0); 
         float minX = width-x0*G_DEF.DRAW_SCALE; 
         float minY = y0*G_DEF.DRAW_SCALE;
         float wX = -(x1-x0)*G_DEF.DRAW_SCALE;
         float hY = (y1-y0)*G_DEF.DRAW_SCALE;        
         float centX = minX+wX/2;
         float centY = minY+hY/2;
         rect(minX, minY, wX, hY );
      line( centX-10, centY, centX+10, centY );
      line( centX, centY-10, centX, centY+10 );
        if (bKalmanEnabled) {
             x0 = (float)filter_x0.update(tmp_x0);
             y0 = (float)filter_y0.update(tmp_y0);
             x1 = (float)filter_x1.update(tmp_x1);
             y1 = (float)filter_y1.update(tmp_y1);
         }
         else {
             x0 = tmp_x0;
             y0 = tmp_y0;
             x1 = tmp_x1;
             y1 = tmp_y1;
         }
         stroke(255,0,0); 
         minX = width-x0*G_DEF.DRAW_SCALE; 
         minY = y0*G_DEF.DRAW_SCALE;
         wX = -(x1-x0)*G_DEF.DRAW_SCALE;
         hY = (y1-y0)*G_DEF.DRAW_SCALE;        
         centX = minX+wX/2;
         centY = minY+hY/2;
         
         rect(minX, minY, wX, hY );

         
         line( centX-10, centY, centX+10, centY );
         line( centX, centY-10, centX, centY+10 );
         stroke(0,0,255);
         line(lastCenter.x, lastCenter.y,centX, centY);
         lastCenter.x = centX;
         lastCenter.y = centY;
         
   }
   popStyle();
}

// ************************************************************
//              CONVERT PIXEL STREAM BUFFER TO PIMAGE
// ************************************************************
void buff2pixFrame(byte[][] pixBuff, PImage dstImg, request_t req) {
  
  int Y0 = 0, U = 0, Y1 = 0, V = 0;
  int Y2 = 0, Y3 = 0, Y4 = 0;
  int reqParam = req.getParam();
  
  dstImg.loadPixels();
  
	for (int y = 0, l = 0, x = 0; y < G_DEF.F_H; y++, x = 0)
		while (x < reqParam) {
			Y0 = int(pixBuff[y][x++]); //Cb Y0
			U = int(pixBuff[y][x++]); //Y0 U - Cb
			Y1 = int(pixBuff[y][x++]); //Cr Y1
			V = int(pixBuff[y][x++]); //Y1 V - Cr
			dstImg.pixels[l++] = YUV2RGB(Y0,U,V);
			dstImg.pixels[l++] = YUV2RGB(Y1,U,V);
		}
    dstImg.updatePixels();  
}
  
// ************************************************************
//                     YUV TO RGB
// ************************************************************

color YUV21RGB(int Y, int Cb, int Cr) {
     // from OV7670 Software Application note
     float R = Y + 1.371*(Cr-128);
     float G = Y - 0.698*(Cr-128)+0.336*(Cb-128);
     float B = Y + 1.732*(Cb-128);
	
     return color(R, G, B);
}

color YUV2RGB(int Y, int Cb, int Cr) {
     // from OV7670 Software Application note
    int C = Y - 16;
	int D = Cb - 128;
	int E = Cr - 128;
	
	float R = (298*C+409*E+128)/256;
	float G = (298*C-100*D-208*E+128)/256;
	float B = (298*C+516*D+128)/256;
    return color(R, G, B);
}

// ************************************************************
//                      RGB TO YUV
// ************************************************************

color RGB2YUV(int R, int G, int B) {
    // from OV7670 Software Application note
    float Yu = 0.299*R+0.587*G+0.114*B;
    float Cb = 0.568*(B-Y)+128;
    float Cr = 0.713*(R-Y)+128;
	
    return color(Yu, Cb, Cr);
}
// ************************************************************
//
// ************************************************************
void keyPressed() {

  switch (key) {
    case ' ':  int i = request.ordinal()+1;
               if (i >= request_t.values().length) i=0;
               request = request_t.values()[i];
               serialPort.clear();
               reqStatus = requestStatus_t.IDLE;
               
           break; 
   case 'k':  bKalmanEnabled = !bKalmanEnabled;
           break; 
   case '+':  thresh++;
           break; 
   case '-':  thresh--;
           break; 
   case 's':  saveFrame(); break; 
   default: break;
  }
}
// ************************************************************
//
// ************************************************************

void mousePressed() {
  println(mouseY);
}