import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart';

void main() async {
  runApp(const MyApp());

  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 29) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NJUPT WiFi Login',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedIsp = "NJUPT"; // 默认选择校园网
  String _statusMessage = "未登录";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message, // 显示的消息
      toastLength: Toast.LENGTH_SHORT, // 显示时长 (SHORT 或 LONG)
      gravity: ToastGravity.TOP, // 显示位置 (BOTTOM, CENTER, TOP)
      timeInSecForIosWeb: 2, // iOS 和 Web 平台的显示时长 (秒)
      fontSize: 16.0, // 字体大小
    );
  }

  Future<void> _loadUserData() async {
    final pref = await SharedPreferences.getInstance();
    _usernameController.text = pref.getString('username') ?? '';
    _passwordController.text = pref.getString('password') ?? '';
    setState(() {
      _selectedIsp = pref.getString('isp') ?? 'NJUPT';
    });
  }

  Future<void> _saveUserData() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString('username', _usernameController.text);
    await pref.setString('password', _passwordController.text);
    await pref.setString('isp', _selectedIsp);
    showToast("信息已保存");
  }

  Future<String?> _getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          return addr.address; // 返回 IPv4 地址
        }
      }
    }
    return null;
  }

  Future<void> _login() async {
    // 检测是否连接到WiFi
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.wifi)) {
      setState(() {
        _statusMessage = "未连接到WiFi";
      });
      showToast(_statusMessage);
      return;
    }

    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = "请填写完整的登录信息";
      });
      showToast(_statusMessage);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 根据ISP选择修改账号格式
    String formattedAccount = username;
    if (_selectedIsp == "CMCC") {
      formattedAccount = ",0,$username@cmcc";
    } else if (_selectedIsp == "CHINANET") {
      formattedAccount = ",0,$username@njxy";
    } else {
      formattedAccount = ",0,$username";
    }

    // 获取网络信息
    final ip = await _getLocalIp() ?? "";

    print("IP: $ip");

    // 构造目标URL
    final loginUrl =
        "https://10.10.244.11:802/eportal/portal/login/?callback=dr1003&login_method=1&"
        "user_account=$formattedAccount&user_password=$password&wlan_user_ip=$ip&"
        "wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=4.1.3&terminal_type=1&v=3576&lang=en";

    // 设置请求头
    final headers = {
      "Accept": "*/*",
      "Accept-Encoding": "gzip, deflate",
      "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
      "Cache-Control": "max-age=0",
      "Connection": "keep-alive",
      "Content-Type": "application/x-www-form-urlencoded",
      "Host": "p.njupt.edu.cn:802",
      "Origin": "https://p.njupt.edu.cn",
      "Referer": "https://p.njupt.edu.cn/",
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.75 Safari/537.36 Edg/86.0.622.38"
    };

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      final request = await httpClient.getUrl(Uri.parse(loginUrl));
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      final response = await request.close();
      print("response ok");

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = "登录成功";
        });
      } else {
        setState(() {
          _statusMessage = "登录失败，服务器错误";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "网络异常: $e";
      });
    }

    print(_statusMessage);
    setState(() {
      _isLoading = false;
    });
    showToast(_statusMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NJUPT 校园网登录")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("选择ISP：", style: TextStyle(fontSize: 16)),
            ListTile(
              title: const Text('中国移动 CMCC'),
              leading: Radio<String>(
                value: "CMCC",
                groupValue: _selectedIsp,
                onChanged: (value) {
                  setState(() {
                    _selectedIsp = value!;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('中国电信 CHINANET'),
              leading: Radio<String>(
                value: "CHINANET",
                groupValue: _selectedIsp,
                onChanged: (value) {
                  setState(() {
                    _selectedIsp = value!;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('默认校园网 NJUPT'),
              leading: Radio<String>(
                value: "NJUPT",
                groupValue: _selectedIsp,
                onChanged: (value) {
                  setState(() {
                    _selectedIsp = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "账号"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "密码"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _saveUserData();
                setState(() {
                  _statusMessage = "信息已保存";
                });
              },
              child: const Text("保存"),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() {
                          _isLoading = true;
                        });
                        await _login();
                        setState(() {
                          _isLoading = false;
                        });
                      },
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("登录", style: TextStyle(fontSize: 32)),
                      ),
              ),
            ),
            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }
}
