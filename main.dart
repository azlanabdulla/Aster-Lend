import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

const String LOGIN_KEY = 'currentUser';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('users');
  await Hive.openBox('app'); // box for login session
  runApp(MyApp());
}

// Hash password for basic local security
String hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

class Debt {
  String person;
  double amount;
  bool isLend;
  bool settled;
  Debt(this.person, this.amount, this.isLend, {this.settled = false});

  Map<String, dynamic> toMap() => {
        'person': person,
        'amount': amount,
        'isLend': isLend,
        'settled': settled,
      };

  static Debt fromMap(Map map) => Debt(
        map['person'],
        map['amount'],
        map['isLend'],
        settled: map['settled'] ?? false,
      );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Box userBox = Hive.box('users');
  Box appBox = Hive.box('app');
  String? loggedInUserEmail;
  String? loggedInUserName;
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  bool isLoginMode = true;

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Restore session if it exists
    final session = appBox.get(LOGIN_KEY);
    if (session != null &&
        session['email'] != null &&
        session['username'] != null) {
      loggedInUserEmail = session['email'];
      loggedInUserName = session['username'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'ASTOR Debt Manager',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Montserrat',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: (loggedInUserEmail == null || loggedInUserName == null)
          ? authScreen()
          : DebtListScreen(
              email: loggedInUserEmail!,
              username: loggedInUserName!,
              onLogout: logout),
      debugShowCheckedModeBanner: false,
    );
  }

  void logout() {
    setState(() {
      loggedInUserEmail = null;
      loggedInUserName = null;
      emailController.clear();
      passwordController.clear();
      usernameController.clear();
      isLoginMode = true;
      appBox.delete(LOGIN_KEY); // clear saved login session
    });
  }

  Widget starA() {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Text(
        'A',
        style: TextStyle(
          fontSize: 72,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          foreground: Paint()
            ..shader = LinearGradient(
              colors: <Color>[Color(0xFFFFD700), Color(0xFFFBC02D)],
            ).createShader(Rect.fromLTWH(0.0, 0.0, 60.0, 80.0)),
        ),
      ),
    );
  }

  Widget authScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLoginMode ? "Login" : "Create Account"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              starA(),
              Text(
                "Welcome to ASTOR",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700]),
              ),
              SizedBox(height: 16),
              Text(
                isLoginMode
                    ? "Login to manage your debts securely"
                    : "Create an account to start managing your debts",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 28),
              if (!isLoginMode)
                Column(
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: "Username",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final email = emailController.text.trim().toLowerCase();
                    final password = passwordController.text.trim();
                    final username = usernameController.text.trim();
                    if (!_validateEmail(email)) {
                      _showMessage("Please enter a valid email address");
                      return;
                    }
                    if (password.length < 6) {
                      _showMessage("Password must be at least 6 characters");
                      return;
                    }
                    if (!isLoginMode && username.isEmpty) {
                      _showMessage("Username is required");
                      return;
                    }
                    if (isLoginMode) {
                      _handleLogin(email, password);
                    } else {
                      _handleRegister(email, password, username);
                    }
                  },
                  child: Text(
                    isLoginMode ? "Login" : "Create Account",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLoginMode = !isLoginMode;
                    emailController.clear();
                    passwordController.clear();
                    usernameController.clear();
                  });
                },
                child: Text(isLoginMode
                    ? "Don't have an account? Create one"
                    : "Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}').hasMatch(email);
  }

  void _showMessage(String msg) {
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  }

  void _handleRegister(String email, String password, String username) {
    if (userBox.containsKey(email)) {
      _showMessage("Account with this email already exists!");
      return;
    }
    final hashedPassword = hashPassword(password);
    userBox.put(email, {
      'password': hashedPassword,
      'username': username,
      'debts': <dynamic>[]
    });
    _showMessage("Account successfully created! Please login.");
    setState(() {
      isLoginMode = true;
      emailController.clear();
      passwordController.clear();
      usernameController.clear();
    });
  }

  void _handleLogin(String email, String password) {
    if (!userBox.containsKey(email)) {
      _showMessage("No account found with this email.");
      return;
    }
    final userData = userBox.get(email);
    if (userData == null) {
      _showMessage("User data invalid.");
      return;
    }
    final hashedPassword = hashPassword(password);
    if (userData['password'] != hashedPassword) {
      _showMessage("Incorrect password.");
      return;
    }
    // Save login session (persist!)
    appBox.put(LOGIN_KEY, {'email': email, 'username': userData['username']});
    setState(() {
      loggedInUserEmail = email;
      loggedInUserName = userData['username'] ?? "User";
    });
  }
}

class DebtListScreen extends StatefulWidget {
  final String email;
  final String username;
  final VoidCallback onLogout;

  DebtListScreen(
      {required this.email, required this.username, required this.onLogout});

  @override
  _DebtListScreenState createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  late Box userBox;
  List<Debt> debts = [];

  TextEditingController personController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  bool isLend = true;

  @override
  void initState() {
    super.initState();
    userBox = Hive.box('users');
    loadDebts();
  }

  void loadDebts() {
    final stored = userBox.get(widget.email);
    debts = [];
    if (stored != null && stored['debts'] != null) {
      for (var map in (stored['debts'] as List)) {
        debts.add(Debt.fromMap(Map<String, dynamic>.from(map)));
      }
    }
    setState(() {});
  }

  void saveDebts() {
    final userData = userBox.get(widget.email);
    if (userData == null) return;
    userData['debts'] = debts.map((d) => d.toMap()).toList();
    userBox.put(widget.email, userData);
  }

  void addDebt() {
    final person = personController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (person.isEmpty || amount <= 0) return;
    debts.add(Debt(person, amount, isLend));
    saveDebts();
    loadDebts();
    personController.clear();
    amountController.clear();
  }

  void editDebt(int index) {
    personController.text = debts[index].person;
    amountController.text = debts[index].amount.toString();
    isLend = debts[index].isLend;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text("Edit Debt"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: personController,
                  decoration: InputDecoration(labelText: "Person"),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: "Amount"),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Radio<bool>(
                        value: true,
                        groupValue: isLend,
                        onChanged: (val) => setDialogState(() => isLend = val!)),
                    Text("Lend"),
                    Radio<bool>(
                        value: false,
                        groupValue: isLend,
                        onChanged: (val) => setDialogState(() => isLend = val!)),
                    Text("Borrow"),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  personController.clear();
                  amountController.clear();
                },
                child: Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  final person = personController.text.trim();
                  final amount = double.tryParse(amountController.text.trim()) ?? 0;
                  if (person.isEmpty || amount <= 0) return;
                  debts[index].person = person;
                  debts[index].amount = amount;
                  debts[index].isLend = isLend;
                  saveDebts();
                  loadDebts();
                  Navigator.pop(context);
                  personController.clear();
                  amountController.clear();
                },
                child: Text("Save")),
          ],
        );
      }),
    );
  }

  void clearDebtsConfirm() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text("Clear All Debts?"),
              content: Text(
                  "Are you sure you want to clear all debts for this user? This action cannot be undone."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context), child: Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        debts.clear();
                        saveDebts();
                        Navigator.pop(context);
                      });
                    },
                    child: Text("Clear")),
              ],
            ));
  }

  void deleteDebtConfirm(int index) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text("Delete Debt?"),
              content: Text("Are you sure you want to delete this debt entry?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context), child: Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                      deleteDebt(index);
                      Navigator.pop(context);
                    },
                    child: Text("Delete")),
              ],
            ));
  }

  void deleteDebt(int index) {
    debts.removeAt(index);
    saveDebts();
    loadDebts();
  }

  void toggleSettled(int index) {
    debts[index].settled = !debts[index].settled;
    saveDebts();
    loadDebts();
  }

  double getTotalToReceive() {
    return debts
        .where((d) => d.isLend && !d.settled)
        .fold(0, (sum, d) => sum + d.amount);
  }

  double getTotalToGive() {
    return debts
        .where((d) => !d.isLend && !d.settled)
        .fold(0, (sum, d) => sum + d.amount);
  }

  @override
  Widget build(BuildContext context) {
    final totalReceive = getTotalToReceive();
    final totalGive = getTotalToGive();

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${widget.username}!"),
        actions: [
          IconButton(
              tooltip: "Clear all debts",
              onPressed: clearDebtsConfirm,
              icon: Icon(Icons.delete_forever)),
          IconButton(
              tooltip: "Logout",
              onPressed: widget.onLogout,
              icon: Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.teal.shade50,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text("To Receive",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text("₹${totalReceive.toStringAsFixed(2)}",
                        style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                  ],
                ),
                Column(
                  children: [
                    Text("To Give",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text("₹${totalGive.toStringAsFixed(2)}",
                        style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  controller: personController,
                  decoration: InputDecoration(
                    labelText: "Person",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: "Amount",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Radio<bool>(
                            value: true,
                            groupValue: isLend,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  isLend = val;
                                });
                              }
                            }),
                        Text("Lend"),
                      ],
                    ),
                    SizedBox(width: 24),
                    Row(
                      children: [
                        Radio<bool>(
                            value: false,
                            groupValue: isLend,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  isLend = val;
                                });
                              }
                            }),
                        Text("Borrow"),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(onPressed: addDebt, child: Text("Add Debt")),
              ],
            ),
          ),
          Expanded(
            child: debts.isEmpty
                ? Center(child: Text("No debts added yet"))
                : ListView.builder(
                    itemCount: debts.length,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      var debt = debts[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        elevation: 3,
                        child: ListTile(
                          leading: Icon(
                            debt.isLend
                                ? Icons.arrow_circle_down_sharp
                                : Icons.arrow_circle_up_sharp,
                            color: debt.isLend ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          title: Text(
                            "${debt.person} - ₹${debt.amount.toStringAsFixed(2)}",
                            style: TextStyle(
                                decoration: debt.settled
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none),
                          ),
                          subtitle: Text(debt.isLend ? "Lend" : "Borrow"),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(
                                  tooltip: debt.settled
                                      ? "Mark as unsettled"
                                      : "Mark as settled",
                                  icon: Icon(
                                    debt.settled
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: debt.settled
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    toggleSettled(index);
                                  }),
                              IconButton(
                                  tooltip: "Edit",
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    editDebt(index);
                                  }),
                              IconButton(
                                  tooltip: "Delete",
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    deleteDebtConfirm(index);
                                  }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
