#include "SR04.h"       //libreria Sensore ultrasuoni
#include <Stepper.h>//libreria Stepper motor  
#include <SoftwareSerial.h> //libreria Bluetooth Seriale
#include <DS3231.h>     //libreria Real Time Clock
#include <EEPROM.h>

//CONSTANTS
const int stepsPerRevolution = 2048;  // used to set the number of steps per revolution of the Stepper motor
const int rolePerMinute = 10;         // used to set the rotation speed of the Stepper Motor (0~17 rpm)
#define TRIG_PIN 7                    //Trigger Pin of the Ultrasonic Sensor
#define ECHO_PIN 6                    //Echo Pin of the Ultrasonic Sensor
#define RED 10                        //Pin used to control the Red LED
#define GREEN 11                      //Pin used to control the Green LED
//The following constants are used to simplify EEPROM reading and writing operations
#define RIMANENTI 0
#define ULTIMAYEAR 1
#define ULTIMAMONTH 2
#define ULTIMADAY 3
#define ULTIMAHOUR 4
#define ULTIMAMINUTE 5
#define ULTIMASECOND 6
#define TOTORE 7
#define NEXTYEAR 8
#define NEXTMONTH 9
#define NEXTDAY 10
#define NEXTHOUR 11
#define NEXTMINUTE 12
#define NEXTSECOND 13

//VARIABLES
RTCDateTime dt;                       //used to store the current DateTime
RTCDateTime prossima, ultima;         //used to store the DateTime of the next and last dispensing
long dist;                            //used to store the distance measurement made by the ultrasonic sensor
int rimanenti;                        //used to store the number of dispensing available
boolean abilitated = false;           //used to enable dispensing through proximity
String temp = "";                     //used to store the string coming from the bluetooth
char temp2 = "";                      //used to store the char coming from the bluetooth before merging it into the string temp
int date_time[6];                     //used to store the DateTime to be set as the new DateTime of the RTC
int tot_ore;                          //used to store the automatic dispensing time interval

//INITIAL SETTINGS
SoftwareSerial BTserial(9,8);                     //Initialization of the serial Bluetooth module on pin 8 and 9
Stepper myStepper(stepsPerRevolution, 2, 3, 4, 5); //initialize the stepper library on pins 2 through 5
SR04 sr04 = SR04(ECHO_PIN, TRIG_PIN);              //Initialize the ultrasonic sensor 
DS3231 clock;                                      //Initialize the Clock
    
//this function is used to detect the distance of an object from the sensor
void rilevaDist() {
  dist = sr04.Distance();
}

//this function is used to set the correct DateTime after having received it via Bluetooth
void setTime() {
  clock.setDateTime(date_time[0], date_time[1], date_time[2], date_time[3], date_time[4], date_time[5]);
  dt = clock.getDateTime();
}

//this function is used to read the DateTime received via Bluetooth
void readDateTime(){
  date_time[0]=(temp.substring(1,5)).toInt();   //year
  date_time[1]=(temp.substring(5,7)).toInt();   //month
  date_time[2]=(temp.substring(7,9)).toInt();   //day
  date_time[3]=(temp.substring(9,11)).toInt();  //hour
  date_time[4]=(temp.substring(11,13)).toInt(); //minute
  date_time[5]=0;                               //second
}

//this function is used to manually set the DateTime of the next dispensing after having received it via Bluetooth
void setNext(){
  prossima.year=date_time[0];
  prossima.month=date_time[1];
  prossima.day=date_time[2];
  prossima.hour=date_time[3];
  prossima.minute=date_time[4];
  prossima.second=date_time[5];

  //store the datetime of the next dispensing in slots 8-13 of the EEPROM
  EEPROM.write(NEXTYEAR,prossima.year-2000);
  EEPROM.write(NEXTMONTH,prossima.month);
  EEPROM.write(NEXTDAY,prossima.day);
  EEPROM.write(NEXTHOUR,prossima.hour);
  EEPROM.write(NEXTMINUTE,prossima.minute);
  EEPROM.write(NEXTSECOND,prossima.second);
}

//this function is used to update the informations stored in the EEPROM
void saveInEEPROM(){
  //store the remaining dispensing in the slot 0 of the EEPROM
  EEPROM.write(RIMANENTI,rimanenti);

  //store the datetime of the last dispensing in slots 1-6 of the EEPROM
  EEPROM.write(ULTIMAYEAR,ultima.year-2000);
  EEPROM.write(ULTIMAMONTH,ultima.month);
  EEPROM.write(ULTIMADAY,ultima.day);
  EEPROM.write(ULTIMAHOUR,ultima.hour);
  EEPROM.write(ULTIMAMINUTE,ultima.minute);
  EEPROM.write(ULTIMASECOND,ultima.second);
  
  //store automatic dispensing time interval in slot 7 of the EEPROM
  EEPROM.write(TOTORE,tot_ore);

  //store the datetime of the NEXT dispensing in slots 8-13 of the EEPROM
  EEPROM.write(NEXTYEAR,prossima.year-2000);
  EEPROM.write(NEXTMONTH,prossima.month);
  EEPROM.write(NEXTDAY,prossima.day);
  EEPROM.write(NEXTHOUR,prossima.hour);
  EEPROM.write(NEXTMINUTE,prossima.minute);
  EEPROM.write(NEXTSECOND,prossima.second);
}

//this function is used to read informations stored in the EEPROM
void readFromEEPROM(){
  rimanenti = EEPROM.read(RIMANENTI);
  
  ultima.year = 2000 + EEPROM.read(ULTIMAYEAR);
  ultima.month = EEPROM.read(ULTIMAMONTH);
  ultima.day = EEPROM.read(ULTIMADAY);
  ultima.hour = EEPROM.read(ULTIMAHOUR);
  ultima.minute = EEPROM.read(ULTIMAMINUTE);
  ultima.second = EEPROM.read(ULTIMASECOND);

  tot_ore = EEPROM.read(TOTORE);

  prossima.year = 2000 + EEPROM.read(NEXTYEAR);
  prossima.month = EEPROM.read(NEXTMONTH);
  prossima.day = EEPROM.read(NEXTDAY);
  prossima.hour = EEPROM.read(NEXTHOUR);
  prossima.minute = EEPROM.read(NEXTMINUTE);
  prossima.second = EEPROM.read(NEXTSECOND);
}

//this function is used to send the DateTime when request by the Mobile Application
void sendDatetime() {
  BTserial.print('h');
  BTserial.print(dt.year);   BTserial.print("-");
  BTserial.print(dt.month);  BTserial.print("-");
  BTserial.print(dt.day);    BTserial.print(" ");
  BTserial.print(dt.hour);   BTserial.print(":");
  BTserial.print(dt.minute); BTserial.print(":");
  BTserial.print(dt.second); BTserial.println("");
}

//this function is used to send all the necessary information to the Mobile Application
void sendInfo(){
  BTserial.print("i");

  //remaining dispensing
  BTserial.print(rimanenti);

  //day and hour of the last dispensing
  if(ultima.day<10) BTserial.print('0');
  BTserial.print(ultima.day);
  if(ultima.hour<10) BTserial.print('0');
  BTserial.print(ultima.hour);

  //day and hour of the next dispensing
  if(prossima.day<10) BTserial.print('0');
  BTserial.print(prossima.day);
  if(prossima.hour<10) BTserial.print('0');
  BTserial.print(prossima.hour);

  //sensor status
  if(abilitated) BTserial.print('1'); else BTserial.print('0');

  //automatic dispensing time interval
  BTserial.println(tot_ore);
}

//this function is used to set the next dispensing according to the automatic dispensing time interval
void piuTotOre(){
  prossima = ultima;
  prossima.hour+=tot_ore;

  //if the hour is grater than 24 we have to increase day
  //and if we are in the last day of a month we have to increase also the month 
  //and the same for the year if we are in the 31th of December 
  if(prossima.hour>=24){
    prossima.hour-=24;
    prossima.day+=1;

    //last of february in not leap year
    if(prossima.month==2 and prossima.day >28 and !prossima.year%4==0){
      prossima.day=1;
      prossima.month+=1;
    }

    //last of february in leap year
    else if(prossima.month==2 and prossima.day >29 and prossima.year%4==0){
      prossima.day=1;
      prossima.month+=1;
    }

    //last of April, June, September and November
    else if((prossima.month==4 or prossima.month==6 or prossima.month==9 or prossima.month==11) and prossima.day>=30) {
      prossima.day=1;
      prossima.month+=1;
     }
     
    //last of December  
    else if(prossima.month==12 and prossima.day>=31){
      prossima.day=1;
      prossima.month=1;
      prossima.year+=1;
    }
    
    //last of the remaining months
    else{
      if (prossima.day>=31){
        prossima.day=1;
        prossima.month+=1;
      }
    }

    
  }
}

//this function is used to make a dispensing and to determine the informations relating to it, like last and next dispensing
void eroga() {
  for(int f=0;f<5;f++){
      digitalWrite(GREEN,LOW);
      delay(80);
      digitalWrite(GREEN,HIGH);
      delay(80);
      }
  myStepper.step(550);//turns the motor and therefore the mechanism of 90°
  rimanenti -= 1;                             //decreases the number of remaining dispensing
  if (rimanenti <= 1 and rimanenti > 0) {
    digitalWrite(RED, HIGH);                  //turn the red LED ON to indicate last dispensing available (RED_ON,GREEN_ON)
  }
  else if (rimanenti == 0) {
    digitalWrite(GREEN, LOW);                 //turn the green LED OFF to indicate no more dispensing available
  }
  ultima = dt;               //saving the datetime of the last dispensing
  piuTotOre();                                //calculating the next dispensing
  abilitated = false;                         //disabling of the sensor 
  sendInfo();                                 //send all the new information to the Mobile Application
  saveInEEPROM();                             //updates the values in the EEPROM
}

//this function checks if it's the time for a dispensing and if it is it returns true
bool checkAlarm(){
  if(
    prossima.second == dt.second 
    and
    prossima.minute == dt.minute
    and
    prossima.hour == dt.hour
    and
    prossima.day == dt.day 
    and
    prossima.month == dt.month
    and
    prossima.year == dt.year    
    ){
      return true;
    } else {
      return false;
    }
}

//this function is used to read and fulfill the requests coming from the Mobile Application via Bluetooth
void readFromBT(){
  while(BTserial.available()>0){       //unifies the input into a single String
    temp2=BTserial.read();
    temp+=temp2;
    delay(1);
  }
  
  char opt=(temp.charAt(0));        //check the first character that indicates the type of action to be performed
  switch(opt){
    case '0':                       //request for useful informations
      sendInfo();
      break;
      
    case '1':                       //dispens now
      if (rimanenti>0) eroga();
      break;
     
    case '2':                       //change time interval for automatic dispensing
      tot_ore = (temp.substring(1,3)).toInt();
      EEPROM.write(TOTORE,tot_ore);
      piuTotOre();                  //update the next dispensing according to the new time interval
      sendInfo();                   
      break;
      
    case '3':                       //set datetime for the next dispensing
      readDateTime();
      setNext();
      sendInfo();
      break;
      
    case '4':                       //enable/disable dispensing via proximity
      if(abilitated) abilitated=false;
      else abilitated=true;
      BTserial.print('s');
      if(abilitated) {
        BTserial.println('1');
      } else {
        BTserial.println('0');
      }
      break;
      
    case '5':                       //confirmation that the bowl has been refilled
      rimanenti=3;
      digitalWrite(GREEN, HIGH);
      digitalWrite(RED, LOW);
      EEPROM.write(RIMANENTI,rimanenti);
      BTserial.print('r');
      BTserial.println(rimanenti);
      break;
      
    case '6':                       //set datetime of the RTC
      readDateTime();
      setTime();
      sendDatetime();
      break;
    
    case '7':                       //request for the actual time of the RTC, to control if it is right
      sendDatetime();
      break;
  }
  
  temp="";
}

void setup() {
  clock.begin();
  
  readFromEEPROM();                       //recovering of the information from EEPROM

  myStepper.setSpeed(rolePerMinute);      //set the speed of the Stepper Motor
  
  pinMode(RED, OUTPUT);
  pinMode(GREEN, OUTPUT);

  //turn the LEDs on according to the remaining dispensing:
  //more than 1 remaining --> GREEN
  //1 remaining --> RED and GREEN
  //0 remaining --> RED
  if(rimanenti>1){
    digitalWrite(GREEN,HIGH);
  }
  if (rimanenti <= 1 and rimanenti > 0) {
    digitalWrite(GREEN,HIGH);
    digitalWrite(RED, HIGH);  
  }
  else if (rimanenti == 0) {
    digitalWrite(RED, HIGH);
  }

  BTserial.begin(9600);
  Serial.begin(9600);
  Serial.print("start");
}

void loop() {
  //get the actual datetime
  dt = clock.getDateTime();
  stamp();
  
  //check if there is something available in the serial bluetooth
  if (BTserial.available()>0){
    readFromBT();
  }
  //enable the Ultrasonic Sensor if 4 hours have passed since the last dispensing
  if (!abilitated and (dt.minute == ultima.minute and dt.hour - ultima.hour == 4)) {
    abilitated = true;
    BTserial.print('s');
    BTserial.println('1');
  }

  //dispensing according to the datetime setted as next
  if (rimanenti > 0 and checkAlarm()) {
    eroga();            //dispensing
  }

  //dispensing through proximity
  if (abilitated){
    rilevaDist();
    if  (rimanenti > 0 and dist <= 10) {
      eroga();
    }
  }
  delay(1000);
}

void stamp(){
  Serial.print(dt.year);   Serial.print("-");
  Serial.print(dt.month);  Serial.print("-");
  Serial.print(dt.day);    Serial.print(" ");
  Serial.print(dt.hour);   Serial.print(":");
  Serial.print(dt.minute); Serial.print(":");
  Serial.print(dt.second); Serial.println("");
}
