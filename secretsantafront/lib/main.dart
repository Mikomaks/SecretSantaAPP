import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models/user.dart';
import 'package:web_socket_channel/io.dart';

const String apiUrl = "https://unsocial-milagros-incommutably.ngrok-free.dev";
//const String apiUrl = "http://192.168.1.67:8000";

var auto_update = WebSocketChannel.connect(
  Uri.parse('wss://unsocial-milagros-incommutably.ngrok-free.dev/ws'),
);
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static ThemeMode themer = ThemeMode.light;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void toggleTheme() {
    setState(() {
      MyApp.themer = MyApp.themer == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secret santa',
      themeMode: MyApp.themer,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent[700]!,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
          contrastLevel: 0.5,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent[700]!,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
          contrastLevel: 0.5,
        ),
      ),
      home: const MyHomePage(title: appTitle),
    );
  }
}

const String appTitle = "Secret Santa APP";

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  Timer? _nameDebounce;
  Timer? _emailDebounce;
  List<User> users = [];
  Map<int, int> results = {};
  bool resultsPresent = false;

  @override
  void initState() {
    super.initState();
    fetchUsers();

    auto_update.stream.listen((message) {
      print(message);
      fetchUsers();
    });
    WidgetsBinding.instance.addObserver(this);
    //print("init state called");
  }

  @override //didnt test this
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (auto_update.closeCode != null) {
        auto_update.sink.close();
        auto_update = WebSocketChannel.connect(
          Uri.parse('wss://unsocial-milagros-incommutably.ngrok-free.dev/ws'),
        );
        //If the websocket is dead we create again
        auto_update.stream.listen((message) {
          print(message);
          fetchUsers();
        });
      }
    }
  }

  void onNameChanged(String value) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 100), () {
      var nameEmpty = value.isEmpty;
      //   if (nameEmpty) {
      //     print("Name is empty!");
      //   }

      setState(() => validName = nameEmpty ? false : true);
    });
  }

  void onEmailChanged(String value) {
    _emailDebounce?.cancel();
    _emailDebounce = Timer(const Duration(milliseconds: 150), () {
      //bad email
      var newvalidEmail = EmailValidator.validate(value);
      if (!newvalidEmail) {
        //print("Invalid email: $value");
      }

      setState(() => validEmail = value.isEmpty ? null : newvalidEmail);
    });
  }

  Future<void> processAddingUser() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();

    //print("$name -> $email");

    final url = Uri.parse('$apiUrl/users/add');
    //print(url);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email}),
      );

      if (response.statusCode == 201) {
        print('User added successfully: ${response.body}');
        setState(() {
          nameController.clear();
          emailController.clear();
          validName = null;
          validEmail = null;
          fetchUsers();
          if (resultsPresent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Remember to re-shuffle gifts!",
                  textAlign: TextAlign.center,
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      } else {
        print('Failed to add user. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred while adding user: $e');
    }
  }

  Future<void> fetchUsers() async {
    final url = Uri.parse('$apiUrl/users');
    //print(url);
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        url,
        headers: {"ngrok-skip-browser-warning": "true"},
      );

      if (response.statusCode == 200) {
        final List<User> fetchedUsers = (json.decode(response.body) as List)
            .map((data) => User.fromJson(data))
            .toList();

        setState(() {
          users = fetchedUsers;
          isLoading = false;
        });
      } else {
        throw Exception(
          "Failed to load users in fetchusers! HTTP:{$response.statusCode}",
        );
      }
    } catch (e) {
      print('Error occurred while fetching users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> removeUser(int index) async {
    final url = Uri.parse('$apiUrl/users/remove/$index');
    //print(url);
    try {
      var response = await http.delete(url);
      switch (response.statusCode) {
        case 200:
          print('User removed successfully: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Remember to re-shuffle gifts!",
                textAlign: TextAlign.center,
              ),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {
            fetchUsers();
          });
          break;
        case 404:
          print('User not found. Status code: ${response.statusCode}');
          break;
        default:
          print('Failed to remove user. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred while removing user: $e');
    }
  }

  void confirmRemoveUserDialog(User userTR) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm removing ${userTR.name}'),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                removeUser(userTR.id);
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> startDraws() async {
    final url = Uri.parse('$apiUrl/run_drawing');

    try {
      var response = await http.post(url);

      if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Not enough users to start the draw!",
              textAlign: TextAlign.center,
            ),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Draw started successfully!",
              textAlign: TextAlign.center,
            ),
            duration: Duration(seconds: 2),
          ),
        );
        Map<String, dynamic> decode = jsonDecode(
          response.body,
        ); //this is always a map <string,dynamic> :(
        results = decode.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
        setState(() {
          resultsPresent = true;
        });
        //print(results);
      }
    } catch (e) {
      print('Error occurred while starting draws: $e');
    }
  }

  bool? validEmail;
  bool? validName;
  bool? get validInputData {
    if (validEmail == null || validName == null) {
      return null;
    }
    return validName! && validEmail!;
  }

  bool isLoading = false;
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  Widget buildAddUserForm(bool isNarrow) {
    final fieldSpacing = SizedBox(height: 12);

    if (isNarrow) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: Center(
                  child: SizedBox(
                    width: 320, // sensible width on phones
                    child: TextField(
                      onChanged: onNameChanged,
                      controller: nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        labelText: 'Name',
                        labelStyle: validName == null
                            ? null
                            : TextStyle(
                                color: validName!
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.red,
                              ),
                        suffixIcon: validName == null
                            ? null
                            : (validName!
                                  ? Icon(Icons.check, color: Colors.green)
                                  : Icon(Icons.error, color: Colors.red)),
                      ),
                    ),
                  ),
                ),
              ),
              fieldSpacing,
              SizedBox(
                width: double.infinity,
                child: Center(
                  child: SizedBox(
                    width: 320,
                    child: TextField(
                      onChanged: onEmailChanged,
                      controller: emailController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        labelText: 'Email',
                        labelStyle: validEmail == null
                            ? null
                            : TextStyle(
                                color: validEmail!
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.red,
                              ),
                        suffixIcon: validEmail == null
                            ? null
                            : (validEmail!
                                  ? Icon(Icons.check, color: Colors.green)
                                  : Icon(Icons.error, color: Colors.red)),
                      ),
                    ),
                  ),
                ),
              ),
              fieldSpacing,
              SizedBox(
                width: double.infinity,
                child: Center(
                  child: SizedBox(
                    width: 120,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (validInputData == null)
                          ? null
                          : (validInputData! ? processAddingUser : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (validInputData == null)
                            ? Colors.grey[300]
                            : (validInputData!
                                  ? Colors.lightGreenAccent
                                  : Colors.redAccent),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 160,
                  child: TextField(
                    onChanged: onNameChanged,
                    controller: nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      labelText: 'Name',
                      labelStyle: validName == null
                          ? null
                          : TextStyle(
                              color: validName!
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.red,
                            ),
                      suffixIcon: validName == null
                          ? null
                          : (validName!
                                ? Icon(Icons.check, color: Colors.green)
                                : Icon(Icons.error, color: Colors.red)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    onChanged: onEmailChanged,
                    controller: emailController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      labelText: 'Email',
                      labelStyle: validEmail == null
                          ? null
                          : TextStyle(
                              color: validEmail!
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.red,
                            ),
                      suffixIcon: validEmail == null
                          ? null
                          : (validEmail!
                                ? Icon(Icons.check, color: Colors.green)
                                : Icon(Icons.error, color: Colors.red)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (validInputData == null)
                        ? null
                        : (validInputData! ? processAddingUser : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (validInputData == null)
                          ? Colors.grey[300]
                          : (validInputData!
                                ? Colors.lightGreenAccent
                                : Colors.redAccent),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget getThemeIcon() {
    if (MyApp.themer == ThemeMode.light) {
      return IconButton(
        icon: Icon(Icons.light_mode),
        color: Colors.white,
        onPressed: () {
          (context.findAncestorStateOfType<_MyAppState>())!.toggleTheme();
          setState(() {});
        },
      );
    } else {
      return IconButton(
        icon: Icon(Icons.dark_mode),
        color: Colors.black,
        onPressed: () {
          (context.findAncestorStateOfType<_MyAppState>())!.toggleTheme();
          setState(() {});
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent[700],
        leading: getThemeIcon(),
        actions: [
          if (resultsPresent)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                child: ElevatedButton(
                  child: Text(
                    "Results",
                    style: TextStyle(fontFamily: "Monocraft", fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ResultsPage(users: users, results: results),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
        title: FittedBox(
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 35,
              fontFamily: 'Monocraft',
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.primaryContainer,
              width: 2,
            ),
          ),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE7E6)),
              onLongPress: startDraws,
              onPressed: () => {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Hold me longer :)",
                      textAlign: TextAlign.center,
                    ),
                    duration: Duration(seconds: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    width: 200,
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              },
              child: Text(
                resultsPresent ? "Re-shuffle gifts" : "Start gift shuffle",
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: "Monocraft",
                  fontWeight: FontWeight.bold,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final addUserForm = buildAddUserForm(isNarrow);

          return RefreshIndicator(
            onRefresh: fetchUsers,
            child: Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: users.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return addUserForm;
                  } else {
                    final user = users[index - 1];
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(user.name, textAlign: TextAlign.center),
                        subtitle: Text(user.email, textAlign: TextAlign.center),
                        onTap: () => confirmRemoveUserDialog(user),
                        //
                      ),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    auto_update.sink.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ResultsPage extends StatefulWidget {
  @override
  State<ResultsPage> createState() => _ResultsPageState();

  final Map<int, int> results;
  final List<User> users;

  const ResultsPage({super.key, required this.users, required this.results});
}

enum ResultsMode { menuView, allResults, passThePhone }

class _ResultsPageState extends State<ResultsPage> {
  Widget getThemeIcon() {
    if (MyApp.themer == ThemeMode.light) {
      return IconButton(
        icon: Icon(Icons.light_mode),
        color: Colors.white,
        onPressed: () {
          (context.findAncestorStateOfType<_MyAppState>())!.toggleTheme();
          setState(() {});
        },
      );
    } else {
      return IconButton(
        icon: Icon(Icons.dark_mode),
        color: Colors.black,
        onPressed: () {
          (context.findAncestorStateOfType<_MyAppState>())!.toggleTheme();
          setState(() {});
        },
      );
    }
  }

  int get revealModeIndex {
    if (mode == ResultsMode.menuView) {
      return 0;
    } else if (mode == ResultsMode.allResults) {
      return 1;
    }
    //if passthephone
    return 2;
  }

  SnackBar snackBarForLongerHoldInfo() {
    return SnackBar(
      content: Text("Hold me longer :)", textAlign: TextAlign.center),
      duration: Duration(seconds: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      width: 200,
      behavior: SnackBarBehavior.floating,
    );
  }

  ResultsMode mode = ResultsMode.menuView;

  Widget buildMenuView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        double buttonWidth = maxWidth < 400 ? double.infinity : 400;

        return Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: 10.0,
            children: [
              SizedBox(
                width: buttonWidth,
                height: 50,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment(0.0, 0.01),
                      colors: [
                        Color(0xFFFF0000),
                        Colors.white,
                        Color(0xFFFF0000),
                        Colors.white,
                      ],
                      stops: [0.0, 0.5, 0.5, 1.0],
                      tileMode: TileMode.repeated,
                      transform: GradientRotation(0.5),
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(snackBarForLongerHoldInfo()),
                    },
                    onLongPress: () => setState(() {
                      mode = ResultsMode.allResults;
                    }),
                    label: Text("Show all pairings"),
                    icon: Icon(Icons.list_alt),
                  ),
                ),
              ),
              SizedBox(
                width: buttonWidth,
                height: 50,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment(0.0, 0.01),
                      colors: [
                        Color(0xFFFF0000),
                        Colors.white,
                        Color(0xFFFF0000),
                        Colors.white,
                      ],
                      stops: [0.0, 0.5, 0.5, 1.0],
                      tileMode: TileMode.repeated,
                      transform: GradientRotation(-0.5),
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(snackBarForLongerHoldInfo()),
                    },
                    onLongPress: () => setState(() {
                      mode = ResultsMode.passThePhone;
                    }),
                    label: Text("Private reveal mode"),
                    icon: Icon(Icons.lock),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildAllResults() {
    final entries = widget.results.entries.toList();
    Map<int, User> usersById = {for (var u in widget.users) u.id: u};

    return ListView.builder(
      itemCount: entries.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return SizedBox(
            width: 400,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, left: 20),
                  child: Text(
                    "All pairings",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Monocraft",
                      fontWeight: FontWeight.bold,
                      fontSize: 60,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else if (index == entries.length + 1) {
          //jak tu bedzie return to nie zrobimy out of index :)
          return Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 150,
                child: ElevatedButton(
                  child: Text(
                    "Return",
                    style: TextStyle(fontFamily: "Monocraft", fontSize: 15),
                  ),
                  onPressed: () {
                    setState(() {
                      mode = ResultsMode.menuView;
                    });
                  },
                ),
              ),
            ),
          );
        }

        final giverId = entries[index - 1].key;
        final receiverId = entries[index - 1].value;

        final giverName = usersById[giverId]!.name;
        final receiverName = usersById[receiverId]!.name;

        return Center(
          child: SizedBox(
            width: 400,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      giverName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.arrow_forward_ios_outlined, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      receiverName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildPassThePhone() {
    return Container(
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 400,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20, left: 20),
                    child: Text(
                      "Pass the phone mode",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "Monocraft",
                        fontWeight: FontWeight.bold,
                        fontSize: 60,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Visibility(
            //   visible: true,
            //   child: Row(
            //     children: [
            //       TextField(
            //         controller: null,
            //         decoration: InputDecoration(labelText: 'Name'),
            //       ),

            //       ElevatedButton(onPressed: () => {}, child: Text("Guzik")),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent[700],
        leading: getThemeIcon(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              child: ElevatedButton(
                child: Text(
                  "Users",
                  style: TextStyle(fontFamily: "Monocraft", fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
        title: FittedBox(
          child: Text(
            "$appTitle - Results",
            style: TextStyle(
              fontSize: 35,
              fontFamily: 'Monocraft',
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
      body: Container(
        margin: EdgeInsets.all(12),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primaryContainer,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IndexedStack(
          index: revealModeIndex,
          children: [buildMenuView(), buildAllResults(), buildPassThePhone()],
        ),
      ),
    );
  }
}
