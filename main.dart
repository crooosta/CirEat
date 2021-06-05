// For performing some operations asynchronously
import 'dart:async';
import 'dart:convert';

// For using PlatformException
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CirEat',
      theme: ThemeData(
        primarySwatch: Colors.brown,
      ),
      home: BluetoothApp(),

    );
  }

}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {

  // Initializing the Bluetooth connection state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
// Initializing a global key, as it would help us in showing a SnackBar later
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
// Get the instance of the Bluetooth
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
// Track the Bluetooth connection with the remote device
  BluetoothConnection connection;

  int _deviceState;

  String _actualPage='home';
  bool isDisconnecting = false;

  Map<String, Color> colors = {
    'onBorderColor': Colors.green,
    'offBorderColor': Colors.red,
    'neutralBorderColor': Colors.transparent,
    'onTextColor': Colors.green[700],
    'offTextColor': Colors.red[700],
    'neutralTextColor': Colors.blue,
  };

// To track whether the device is still connected to Bluetooth
  bool get isConnected => connection != null && connection.isConnected;

// Define some variables, which will be required later
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice _device;
  bool _connected = false, _sensor=false;
  bool _isButtonUnavailable = false;
  int _rimanenti;
  int _ultimaDay, _ultimaHour;
  int _prossimaDay, _prossimaHour;
  String _hourCireat;
  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    _deviceState = 0; // neutral

    // If the bluetooth of the device is not enabled,
    // then request permission to turn on bluetooth
    // as the app starts up
    enableBluetooth();

    // Listen for further state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (_bluetoothState == BluetoothState.STATE_OFF) {
          _isButtonUnavailable = true;
        }
        getPairedDevices();
      });
    });
  }

  @override
  void dispose() {
    // Avoid memory leak and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  // Request Bluetooth permission from the user
  Future<void> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  // For retrieving and storing the paired devices
  // in a list.
  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // To get the list of paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  var opt;//opzione di input: ricevo orario info o altro?
  void _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('No device selected');
    } else {
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device.address)
            .then((_connection) {
          print('Connected to the device');
          connection = _connection;
          setState(() {
            _connected = true;
          });
          connection.input.listen((data){
            String _temp;
            _temp = ascii.decode(data);
            _message+=_temp;
            if(_message.contains("\n")) {
              opt=_message.substring(0,1);
              switch(opt){
                case 'i':     //riceve informazioni per homepage
                  setState(() {
                    _rimanenti=int.parse(_message.substring(1,2));
                    _ultimaDay=int.parse(_message.substring(2,4));
                    _ultimaHour=int.parse(_message.substring(4,6));
                    _prossimaDay=int.parse(_message.substring(6,8));
                    _prossimaHour=int.parse(_message.substring(8,10));
                    _sensor=_message.substring(10,11)=='1'? true:false;
                    totOre=int.parse(_message.substring(11,));
                  });
                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext context){
                      return CupertinoAlertDialog(
                        title: Text('Aggiornamento Informazioni'),
                        content: Text("Le informazioni relative a CirEat sono state aggiornate con successo"),
                        actions: [
                          CupertinoDialogAction(
                            child: Text('OK'),
                              onPressed: (){
                                Navigator.pop(context);
                                setState(() {
                                  _actualPage='home';
                                });
                              }
                          )
                        ],
                      );
                    },
                  );
                  break;

                case 'r':   //aggiorno rimanenti
                  setState(() {
                    _rimanenti=int.parse(_message.substring(1,2));
                  });
                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext context){
                      return CupertinoAlertDialog(
                        title: Text('Aggiornamento Informazioni'),
                        content: Text("Le informazioni relative a CirEat sono state aggiornate con successo"),
                        actions: [
                          CupertinoDialogAction(
                            child: Text('OK'),
                            onPressed: (){
                              Navigator.pop(context);
                              setState(() {
                                _actualPage='home';
                              });
                            }
                          )
                        ],
                      );
                    },
                  );
                  break;

                case 'h':    //richiesta orario cireat
                  _hourCireat = _message.substring(1,);
                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext context){
                      return CupertinoAlertDialog(
                        title: Text('Orario CirEat'),
                        content: Text("$_hourCireat"),
                        actions: [
                          CupertinoDialogAction(
                            child: Text('OK'),
                              onPressed: (){
                                Navigator.pop(context);
                                setState(() {
                                  _actualPage='home';
                                });
                              }                          )
                        ],
                      );
                    },
                  );
                  break;

                case 't':  //aggiorno totOre
                  setState(() {
                    totOre=int.parse(_message.substring(1,));
                  });
                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext context){
                      return CupertinoAlertDialog(
                        title: Text('Aggiornamento Informazioni'),
                        content: Text("Le informazioni relative a CirEat sono state aggiornate con successo"),
                        actions: [
                          CupertinoDialogAction(
                            child: Text('OK'),
                              onPressed: (){
                                Navigator.pop(context);
                                setState(() {
                                  _actualPage='home';
                                });
                              }                          )
                        ],
                      );
                    },
                  );
                  break;

                case 's':   //sensore abilitato o no?
                  setState(() {
                    _message.substring(1,2)=='1'? _sensor=true : _sensor=false;
                  });
                  break;
              }
              _message='';
            }
          }).onDone(() {
            if (isDisconnecting) {
              print('Disconnecting locally!');
            } else {
              print('Disconnected remotely!');
            }
            if (this.mounted) {
              setState(()  {
                _connected=false;
                _actualPage='home';
              });
            }
          });
        }).catchError((error) {
          print('Cannot connect, exception occurred');
          print(error);
        });
        show('Device connected');
        setState(() => _isButtonUnavailable = false);
      }
    }
  }


// Method to disconnect bluetooth
  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
      _deviceState = 0;
    });

    await connection.close();
    show('Device disconnected');
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  Future show(
      String message, {
        Duration duration: const Duration(seconds: 3),
      }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    _scaffoldKey.currentState.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }

  var _message='';

  // Now, its time to build the UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _connected ? _homeConnessa(context) : _homeDisconnessa(context),
      );
  }


  Widget _homeDisconnessa(BuildContext context){
    return Scaffold(
        key: _scaffoldKey,
        drawer: _myDrawerDisconnected(context),
        appBar: AppBar(
          title: Text("CirEat"),
          backgroundColor: Colors.brown[700],
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                "Refresh",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.white54,
              onPressed: () async {
                await getPairedDevices().then((_) {
                  show('Device list refreshed');
                });
              },
            ),
          ],
        ),
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Visibility(
                visible: _isButtonUnavailable &&
                    _bluetoothState == BluetoothState.STATE_ON,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.blue,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.bluetooth,size:40),
                    Expanded(
                      child: Text(
                        'Abilita Bluetooth',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Switch(
                      value: _bluetoothState.isEnabled,
                      onChanged: (bool value) {
                        future() async {
                          if (value) {
                            await FlutterBluetoothSerial.instance
                                .requestEnable();
                          } else {
                            await FlutterBluetoothSerial.instance
                                .requestDisable();
                          }

                          await getPairedDevices();
                          _isButtonUnavailable = false;

                          if (_connected) {
                            _disconnect();
                          }
                        }

                        future().then((_) {
                          setState(() {});
                        });
                      },
                    )
                  ],
                ),
              ),
              Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          "Dispositivi Associati",
                          style: TextStyle(fontSize: 24, color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Device:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton(
                              items: _getDeviceItems(),
                              onChanged: (value) =>
                                  setState(() => _device = value),
                              value: _devicesList.isNotEmpty ? _device : null,
                            ),
                          ],
                        ),
                      ),
                      RaisedButton(
                        onPressed: _isButtonUnavailable
                            ? null
                            : _connected ? _disconnect : _connect,
                        child:
                        Text('Connetti'),
                      ),
                    ],
                  ),
            ],
          ),
        )
    );
  }

  Widget _homeConnessa(BuildContext context){
    switch (_actualPage){
      case 'home':
        return _home(context);
        break;
      case 'set_time':
        return _orarioRTC(context);
        break;
      case 'send':
        return _send(context);
        break;
    }
  }

  Widget _home(BuildContext context){
    return Scaffold(
      key: _scaffoldKey,
      drawer: _myDrawerConnected(context),
      appBar: AppBar(
        title: Text("CirEat"),
        backgroundColor: Colors.brown[700],
        actions: <Widget>[
          FlatButton.icon(
            icon: Icon(
              Icons.bluetooth_disabled,
              color: Colors.white,
              ),
            label: Text(
              "Disconnetti",
              style: TextStyle(
                color: Colors.white,
                ),
              ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              ),
            splashColor: Colors.white54,
            onPressed: ()  {
              _disconnect();
              show('Disconnesso');
            },
          )
        ],
      ),
      body:Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children:[
                Text("Dispositivo Connesso",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.lightGreen,
                  ),
                ),
                SizedBox(width: 15),
                RaisedButton(
                  elevation: 1,
                  child: Text("Richiedi Info",style: TextStyle(color: Colors.lightGreen,fontSize: 10 ),),//Icon(Icons.refresh,color: Colors.lightGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                    ),
                  onPressed: () async{
                    connection.output.add(utf8.encode('0'));
                    await connection.output.allSent;
                  },
                )
              ]
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20,top:5, bottom: 10, right: 20),
              child: Card(
                shape: RoundedRectangleBorder(
                  side: new BorderSide(
                    color: _rimanenti==0
                        ? colors['offBorderColor']
                        : _rimanenti == 1
                        ? Colors.yellow
                        : Colors.green,
                    width: 2
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 6,
                child: Center(
                  heightFactor: 1.8,
                  child: Text(
                    "Erogazioni rimanenti: $_rimanenti",
                    style: TextStyle(
                      fontSize: 18,
                      color: _rimanenti ==0
                        ? colors['offTextColor']
                        : _rimanenti == 1
                        ? Colors.yellow[700]
                        : colors['onTextColor']
                    ),
                  ),
                )
              )
            ),
            Padding(
                padding: const EdgeInsets.only(left:20,bottom:10,right:20),
                child: Card(
                    shape: RoundedRectangleBorder(
                      side: new BorderSide(
                          color: Colors.blue,
                          width: 2
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 6,
                    child:Center(
                        heightFactor: 1.8,
                        child: Text(
                          _ultimaHour==null
                              ? "Ora ultima erogazione sconosciuta"
                              : _ultimaDay==(DateTime.now()).day
                              ? "Ultima erogazione effettuata oggi verso le ore $_ultimaHour "
                              : "Ultima erogazione effettuata giorno $_ultimaDay verso le ore $_ultimaHour " ,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                          ),
                        ),
                      )
                  )
                ),
            Padding(
                padding: const EdgeInsets.only(left:20,bottom:10,right:20),
                child: Card(
                    shape: RoundedRectangleBorder(
                      side: new BorderSide(
                          color: Colors.blue,
                          width: 2
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 6,
                    child:Center(
                      heightFactor: 1.8,
                      child: Text(
                        _prossimaHour==null
                            ? "Ora prossima erogazione sconosciuta"
                            : _prossimaDay==(DateTime.now()).day
                            ? "Prossima erogazione prevista oggi verso le ore $_prossimaHour "
                            : "Prossima erogazione prevista per giorno $_prossimaDay verso le ore $_prossimaHour",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                        ),
                      ),
                    )
                )
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: new BorderSide(
                          color: _sensor ? Colors.green : Colors.red,
                          width: 2
                      ),
                      borderRadius: BorderRadius.circular(18),
                    )
                  ),
                  child: Column(
                    children: [
                      Switch(
                          value: _sensor,
                          onChanged: (bool value) {
                            value ? _dialogMode='sensore' : _dialogMode='sensoff';
                            _myDialogControl(context);
                          }
                      ),
                      Text(_sensor? "Sensore\nON" :"Sensore\nOFF",textAlign: TextAlign.center),
                    ],
                  ),
                ),
                SizedBox(width: 90),
                Container(
                  height: 94,
                  width: 70,
                  decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: new BorderSide(
                            color: Colors.blue,
                            width: 2
                        ),
                        borderRadius: BorderRadius.circular(18),
                      )
                  ),
                  child:Center(
                    child: Text("Eroga\nogni\n$totOre ore",textAlign: TextAlign.center,),
                  )

                ),
              ],
            ),
            SizedBox(height: 10),
            RaisedButton(
              elevation: 15,
              color: Colors.brown[400],
              splashColor: Colors.brown[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.0),
              ),
              child: Text(
                "Cosa vuoi fare?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
              onPressed:(){
                setState(() {
                  _actualPage='send';
                });
              },
            ),
          ],
        ),
      )
  );
  }

  String _dialogMode;
  void _myDialogControl(BuildContext context){
    var dialog= CupertinoAlertDialog(
      title: _dialogMode=='eroga'
          ? Text("Conferma erogazione")
          : _dialogMode== 'sensore'
          ? Text("Conferma attivazione sensore")
          : _dialogMode== 'sensoff'
          ? Text("Conferma disattivazione sensore")
          : _dialogMode=='ricarica'
          ? Text("Conferma Ricarica")
          : _dialogMode=='imposta'
          ? Text("Imposta orario CirEat")
          : _dialogMode=='tot_ore'
          ? Text("Erogazione a intervalli di tempo")
          : _dialogMode=='next'
          ? Text("Erogazione Temporizzata")
          : _dialogMode=='nono'
          ? Text("Croccantini Terminati") :
          null,
      content: _dialogMode=='eroga'
          ? Text("Sei sicuro di voler erogare adesso?")
          : _dialogMode== 'sensore'
          ? Text("Sei sicuro di voler attivare il sensore di prossimità?")
          : _dialogMode== 'sensoff'
          ? Text("Sei sicuro di voler disattivare il sensore di prossimità?")
          : _dialogMode=='ricarica'
          ? Text("Sei sicuro di aver ricaricato CirEat?")
          : _dialogMode=='imposta'
          ? Text("Sei sicuro di voler modificare l'orario di CirEat?")
          : _dialogMode=='tot_ore'
          ? Text("Vuoi erogare una porzione ogni $totOre ore?")
          : _dialogMode=='next'
          ? Text("Vuoi erogare la prossima porzione giorno ${selectedDate.day}-${selectedDate.month}-${selectedDate.year} alle ore ${selectedDate.hour}:${selectedDate.minute}?")
          : _dialogMode=='nono'
          ? Text("Ricarica CirEat per effettuare un'erogazione")
          : null,
      actions: _dialogMode=='nono'
      ? [
        CupertinoDialogAction(
              child: Text('OK'),
              onPressed: ()=> Navigator.pop(context),
            )
      ]
      : [
        CupertinoDialogAction(
          child: Text('Conferma'),
          onPressed: () async{
            _dialogMode=='eroga'
                ? connection.output.add(utf8.encode("1"))
                : _dialogMode== 'sensore'
                ? connection.output.add(utf8.encode("4"))
                : _dialogMode== 'sensoff'
                ? connection.output.add(utf8.encode("4"))
                : _dialogMode=='ricarica'
                ? connection.output.add(utf8.encode("5"))
                : _dialogMode=='imposta'
                ? _setRTCtime()
                : _dialogMode=='tot_ore'
                ? totOre<10 ? connection.output.add(utf8.encode("20$totOre")) : connection.output.add(utf8.encode("2$totOre"))
                : _dialogMode=='next'
                ? connection.output.add(utf8.encode("3"+_datetime))
                : null;
            await connection.output.allSent;
            Navigator.pop(context);
          },
        ),
        CupertinoDialogAction(
          child: Text('Annulla'),
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
        )
      ],
    );
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return dialog;
        });
  }

  int totOre;
  Future<void> _selectTotOre(BuildContext context) async {
    showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
            height: 400,
            color: Color.fromARGB(255, 255, 255, 255),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 300,
                  child: CupertinoPicker(
                    itemExtent: 30,
                    children: [
                      for(int i=1;i<25;i++) Text(i.toString())
                    ],
                    onSelectedItemChanged: (value){
                      totOre=value+1;
                    },
                  ),
                ),
                CupertinoDialogAction(
                  child: Text('OK'),
                  onPressed: ()async{
                    _dialogMode='tot_ore';
                    Navigator.pop(context);
                    _myDialogControl(context);
                  },
                )
              ],
            )));
  }

  Future<void> _nextErogazione(BuildContext context) async{
    showCupertinoModalPopup(context: context,
        builder: (_) => Container(
            height: 400,
            color: Color.fromARGB(255, 255, 255, 255),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 300,
                  child: CupertinoDatePicker(
                      initialDateTime: DateTime.now(),
                      use24hFormat: true,
                      onDateTimeChanged: (val) {
                        selectedDate= val;
                      }),
                ),
                CupertinoDialogAction(
                  child: Text('OK'),
                  onPressed: () {
                    _translateDateTime();
                    _dialogMode='next';
                    Navigator.of(context).pop();
                    _myDialogControl(context);

                  },
                )
              ],
            ))
        );
  }

  Widget _send(BuildContext context){
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("CirEat"),
          backgroundColor: Colors.brown[700],
          leading: FlatButton(
              child:Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.white54,
              onPressed: (){
                setState(() {
                  _actualPage='home';
                });
              }
          ),
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(
                Icons.bluetooth_disabled,
                color: Colors.white,
              ),
              label: Text(
                "Disconnetti",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.white54,
              onPressed: ()  {
                _disconnect();
                show('Disconnesso');
              },
            )
          ],
        ),
        body: Container(
          margin: EdgeInsets.only(left:5,right: 5),
          alignment: Alignment.center,
            child: Column(
              children: [
                SizedBox(height:10),
                ListTile(
                  leading: Icon(Icons.fastfood_outlined,color:Colors.brown[600]),
                  title: Text("Eroga adesso"),
                  shape: StadiumBorder(
                      side: BorderSide(
                          color: Colors.brown[400],
                          width: 2.5
                      )
                  ),
                  onTap: (){
                    _rimanenti>0 ? _dialogMode='eroga' : _dialogMode='nono';
                    _myDialogControl(context);
                  },
                ),
                SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.hourglass_bottom_outlined,color:Colors.brown[600]),
                  title: Text("Scegli ogni quante ore erogare"),
                  shape: StadiumBorder(
                      side: BorderSide(
                          color: Colors.brown[400],
                          width: 2.5
                      )
                  ),
                  onTap: (){
                    _selectTotOre(context);
                  },
                ),
                SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.access_time_outlined,color:Colors.brown[600]),
                  title:Text("Scegli l'orario della prossima erogazione"),
                  shape: StadiumBorder(
                      side: BorderSide(
                          color: Colors.brown[400],
                          width: 2.5
                      )
                  ),
                  onTap: (){
                    _nextErogazione(context);
                  },
                ),
                SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.format_color_fill,color:Colors.brown[600]),
                  title: Text("Conferma ricarica CirEat"),
                  shape: StadiumBorder(
                      side: BorderSide(
                          color: Colors.brown[400],
                          width: 2.5
                      )
                  ),
                  onTap: (){
                    _dialogMode='ricarica';
                    _myDialogControl(context);
                  },
                ),

              ],
            )
        )
    );
  }

  DateTime selectedDate= DateTime.now();

  Future<void> _selectDateTime(BuildContext context) async {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
          height: 400,
          color: Color.fromARGB(255, 255, 255, 255),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
            height: 300,
            child: CupertinoDatePicker(
                initialDateTime: selectedDate,
                use24hFormat: true,
                onDateTimeChanged: (val) {
                   selectedDate= val;
                }),
          ),
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: (){
                  Navigator.of(context).pop();
                  _dialogMode='imposta';
                  _myDialogControl(context);
                },
              )
  ],
          )));
  }


  String _datetime;
  void _translateDateTime(){
    String mese, giorno,ora,minuti;
    selectedDate.month <10 ? mese='0${selectedDate.month}' : mese = '${selectedDate.month}';
    selectedDate.day <10 ? giorno='0${selectedDate.day}' : giorno = '${selectedDate.day}';
    selectedDate.hour <10 ? ora='0${selectedDate.hour}' : ora = '${selectedDate.hour}';
    selectedDate.minute <10 ? minuti='0${selectedDate.minute}' : minuti='${selectedDate.minute}';
    _datetime='${selectedDate.year}'+mese +giorno + ora + minuti;
  }
  void _setRTCtime() async{
    _translateDateTime();
    connection.output.add(utf8.encode("6"+_datetime));
    await connection.output.allSent;
    setState(() {
    });
  }

  void _controllaOra() async{
     connection.output.add(utf8.encode("7"));
     await connection.output.allSent;
  }

  Widget _orarioRTC(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Orario CirEat'),
          backgroundColor: Colors.brown[700],
          leading: FlatButton(
              child:Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.white54,
              onPressed: (){
                setState(() {
                  _actualPage='home';
                });
              }
          ),
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(
                Icons.bluetooth_disabled,
                color: Colors.white,
              ),
              label: Text(
                "Disconnetti",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.white54,
              onPressed: ()  {
                _disconnect();
                show('Disconnesso');
              },
            )
          ],
        ),
        body: Container(
            alignment: Alignment.topCenter,
            margin: EdgeInsets.only(left:5,right: 5),
            child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20,bottom:15),
                child: Text("Imposta l'orario del tuo CirEat",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[700],
                  ),
                ),
              ),
              Icon(Icons.access_time,size: 50,color: Colors.brown[700]),
              SizedBox(height: 30),
              ListTile(
                leading: Icon(Icons.more_time_outlined,color:Colors.brown[600]),
                title: Text("Imposta manualmente"),
                shape: StadiumBorder(
                    side: BorderSide(
                        color: Colors.brown[400],
                        width: 2.5
                    )
                ),
                onTap: (){
                  _selectDateTime(context);
                },
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.access_time,color:Colors.brown[600]),
                title: Text("Imposta Automaticamente"),
                shape: StadiumBorder(
                    side: BorderSide(
                        color: Colors.brown[400],
                        width: 2.5
                    )
                ),
                onTap: (){
                  _dialogMode='imposta';
                  selectedDate= DateTime.now();
                  _myDialogControl(context);
                },
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.help_outline_outlined,color:Colors.brown[600]),
                title: Text("Controlla Orario CirEat"),
                shape: StadiumBorder(
                    side: BorderSide(
                        color: Colors.brown[400],
                        width: 2.5
                    )
                ),
                onTap: (){
                  _controllaOra();
                },
              ),
            ],
          )
        )
    );
  }

  Widget _myDrawerConnected(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          UserAccountsDrawerHeader(
            decoration:BoxDecoration(color:Colors.brown),
            accountName: Text("CirEat"),
            accountEmail: Text("Fai mangiare il tuo piccolo amico"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.brown[300],
              child: Icon(Icons.pets, size: 60, color: Colors.black),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('HOME'),
            onTap: () {
              setState(() {
                _actualPage='home';
              });
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.access_time_outlined),
            title: Text('Imposta Orario CirEat'),
            onTap: () {
              setState(() {
                _actualPage='set_time';
              });
            },
          ),
          Divider(),
        ],
      ),
    );
  }

  Widget _myDrawerDisconnected(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          UserAccountsDrawerHeader(
            decoration:BoxDecoration(color:Colors.brown),
            accountName: Text("Cireat"),
            accountEmail: Text("Fai mangiare il tuo piccolo amico"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.brown[300],
              child: Icon(Icons.pets, size: 60, color: Colors.black),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('HOME'),
            onTap: () {
              setState(() {
                _actualPage='home';
              });
            },
          ),
        ],
      ),
    );
  }

}







