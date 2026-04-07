import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const HanabnihoApp());
}

class HanabnihoApp extends StatelessWidget {
  const HanabnihoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حنبنيهو',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(primarySwatch: Colors.green),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batterySubscription;
  bool _isCharging = false;

  bool _isAutoSupportEnabled = true;
  InterstitialAd? _interstitialAd;
  int _adsWatched = 0;
  bool _isBreakTime = false;
  int _breakSeconds = 120;
  Timer? _breakTimer;
  Timer? _nextAdTimer;

  // في النسخة النهائية المربوطة بفايربيس، سيتم جلب هذا الكود من قاعدة البيانات
  String currentAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; 

  final List<Widget> _pages = [
    const HomeTab(),
    const Center(child: Text('صفحة المشاريع الكاملة (قريباً)', style: TextStyle(fontSize: 18))),
    const MyImpactTab(),
  ];

  @override
  void initState() {
    super.initState();
    _batterySubscription = _battery.onBatteryStateChanged.listen((BatteryState state) {
      setState(() {
        _isCharging = (state == BatteryState.charging);
        if (_isCharging) {
          _handleChargingStarted();
        } else {
          _handleChargingStopped();
        }
      });
    });
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    _breakTimer?.cancel();
    _nextAdTimer?.cancel();
    _interstitialAd?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _handleChargingStarted() {
    if (_isAutoSupportEnabled) {
      WakelockPlus.enable();
      _loadAd();
    }
  }

  void _handleChargingStopped() {
    WakelockPlus.disable();
    _nextAdTimer?.cancel();
    _breakTimer?.cancel();
    setState(() {
      _isBreakTime = false;
      _adsWatched = 0;
    });
  }

  void _loadAd() {
    InterstitialAd.load(
      adUnitId: currentAdUnitId, // استخدام المتغير الديناميكي هنا
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _adCompleted();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _adCompleted();
            },
          );
          if (_isCharging && _isAutoSupportEnabled && !_isBreakTime) {
            _interstitialAd!.show();
          }
        },
        onAdFailedToLoad: (error) {
          _nextAdTimer = Timer(const Duration(seconds: 30), _loadAd);
        },
      ),
    );
  }

  void _adCompleted() {
    setState(() {
      _adsWatched++;
    });
    if (_adsWatched >= 5) {
      _startBreakTime();
    } else {
      int delay = Random().nextInt(16) + 15;
      _nextAdTimer = Timer(Duration(seconds: delay), _loadAd);
    }
  }

  void _startBreakTime() {
    setState(() {
      _isBreakTime = true;
      _breakSeconds = 120;
    });
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isCharging || !_isAutoSupportEnabled) {
        timer.cancel();
        return;
      }
      if (_breakSeconds > 0) {
        setState(() {
          _breakSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isBreakTime = false;
          _adsWatched = 0;
        });
        _loadAd();
      }
    });
  }

  void _showAdminLoginDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('دخول الإدارة التقنية', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: passwordController,
            obscureText: true, 
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'أدخل رقمك السري الخاص',
              prefixIcon: Icon(Icons.security),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text == '87654322345678') { 
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const AdminDashboard())
                  );
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرقم السري غير صحيح!'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
              child: const Text('دخول الآدمن'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isCharging ? _buildChargingScreen() : Scaffold(
      appBar: AppBar(
        title: const Text('حنبنيهو', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white70),
            onPressed: () => _showAdminLoginDialog(context),
          )
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.green[700],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'المشاريع'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'أثري'),
        ],
      ),
    );
  }

  Widget _buildChargingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isBreakTime) ...[
                  const Icon(Icons.shield_moon, size: 80, color: Colors.amber),
                  const SizedBox(height: 20),
                  const Text('تأمين العمليات وتحديث البيانات...', 
                    style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('سنواصل البناء التلقائي بعد:\n${(_breakSeconds ~/ 60).toString().padLeft(2, '0')}:${(_breakSeconds % 60).toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.5)),
                ] else ...[
                  Lottie.network('https://lottie.host/28f6e80b-dfb4-4b55-ab19-ff1ee8dd684b/3R9GOMQ1gS.json', width: 250, height: 250),
                  const SizedBox(height: 20),
                  const Text('طاقة جديدة.. أمل جديد!', 
                    style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('المساهمات الحالية في هذه الجلسة: $_adsWatched/5', 
                    style: const TextStyle(fontSize: 16, color: Colors.greenAccent)),
                ],
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الدعم التلقائي المتواصل', style: TextStyle(color: Colors.white, fontSize: 16)),
                  Switch(
                    value: _isAutoSupportEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                      setState(() {
                        _isAutoSupportEnabled = val;
                        if (val) {
                          _handleChargingStarted();
                        } else {
                          _handleChargingStopped();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- الواجهة الرئيسية -----------------
class HomeTab extends StatelessWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: Colors.white,
          width: double.infinity,
          child: Column(
            children: const [
              Text('إجمالي مساهمات السودانيين اليوم', style: TextStyle(fontSize: 16, color: Colors.black54)),
              SizedBox(height: 10),
              Text('0.00 SDG', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(15.0),
          child: Align(alignment: Alignment.centerRight, child: Text('اختر مشروعاً لتدعمه الآن:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('projects').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد مشاريع حالياً.. قم بإضافتها من لوحة التحكم!'));
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var project = snapshot.data!.docs[index];
                  return _buildTargetedProjectCard(project.id, project['title'] ?? '', project['text'] ?? '', (project['progress'] ?? 0).toDouble());
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTargetedProjectCard(String projectId, String title, String progressText, double progressValue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progressValue, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!), minHeight: 8),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(progressText, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () { print("دعم يدوي للمشروع: $projectId"); },
                  icon: const Icon(Icons.play_circle_fill, size: 18),
                  label: const Text('ادعم الهدف'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- صفحة "أثري" -----------------
class MyImpactTab extends StatefulWidget {
  const MyImpactTab({Key? key}) : super(key: key);
  @override
  State<MyImpactTab> createState() => _MyImpactTabState();
}
class _MyImpactTabState extends State<MyImpactTab> {
  int userPoints = 150;
  int dailyStreak = 5;
  String currentRank = 'بناء الأمل';

  void _doubleImpact() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تحميل إعلان المكافأة...'), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 5,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [Colors.green[800]!, Colors.green[500]!])),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.shield, size: 60, color: Colors.amber),
                  const SizedBox(height: 10),
                  Text('الرتبة: $currentRank', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 5),
                  const Text('باقي 50 مساهمة للترقية', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  const Divider(height: 30, thickness: 1, color: Colors.white30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('سلسلة العطاء', '$dailyStreak أيام', Icons.local_fire_department, Colors.orangeAccent),
                      _buildStatColumn('الرصيد', '$userPoints طوبة', Icons.construction, Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _doubleImpact, icon: const Icon(Icons.ondemand_video, size: 24), label: const Text('ضاعف أثرك الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ],
      ),
    );
  }
  Widget _buildStatColumn(String title, String value, IconData icon, Color iconColor) {
    return Column(children: [Icon(icon, color: iconColor, size: 30), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70))]);
  }
}

// ----------------- لوحة تحكم الإعمار (الصفحة الرئيسية للآدمن) -----------------
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _progressController = TextEditingController();

  Future<void> _uploadProject() async {
    if (_titleController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('projects').add({
      'title': _titleController.text, 'text': _descController.text, 'progress': double.parse(_progressController.text) / 100, 'createdAt': FieldValue.serverTimestamp(),
    });
    _titleController.clear(); _descController.clear(); _progressController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النشر!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الإعمار (الرئيسية)'), backgroundColor: Colors.black87),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminNotificationsPage())), icon: const Icon(Icons.campaign, color: Colors.white), label: const Text('الطوارئ (صفحة 6)', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminFinancialReportsPage())), icon: const Icon(Icons.monetization_on, color: Colors.white), label: const Text('الأرباح (صفحة 7)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[500]))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUserManagementPage())), icon: const Icon(Icons.people_alt, color: Colors.white), label: const Text('المستخدمين (صفحة 8)', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple[600]))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsPage())), icon: const Icon(Icons.settings, color: Colors.white), label: const Text('إعدادات التطبيق (صفحة 9)', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAdSettingsPage())), icon: const Icon(Icons.ad_units, color: Colors.white), label: const Text('التحكم في الإعلانات (صفحة 10)', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]))),

            const Divider(height: 40, thickness: 2),
            const Text('إضافة مشروع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _progressController, decoration: const InputDecoration(labelText: 'نسبة الإنجاز (0-100)', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _uploadProject, style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]), child: const Text('اعتماد ونشر', style: TextStyle(color: Colors.white)))),
          ],
        ),
      ),
    );
  }
}

// ----------------- الصفحات الفرعية المفرغة اختصاراً -----------------
class AdminNotificationsPage extends StatelessWidget { const AdminNotificationsPage({Key? key}) : super(key: key); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('الإشعارات')), body: const Center(child: Text('صفحة الإشعارات'))); } }
class AdminFinancialReportsPage extends StatelessWidget { const AdminFinancialReportsPage({Key? key}) : super(key: key); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('التقارير المالية')), body: const Center(child: Text('صفحة التقارير'))); } }
class AdminUserManagementPage extends StatelessWidget { const AdminUserManagementPage({Key? key}) : super(key: key); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('المستخدمين')), body: const Center(child: Text('صفحة المستخدمين'))); } }
class AdminSettingsPage extends StatelessWidget { const AdminSettingsPage({Key? key}) : super(key: key); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('الإعدادات')), body: const Center(child: Text('صفحة الإعدادات'))); } }

// ----------------- الصفحة رقم 10: التحكم والإدارة في الإعلانات وتغيير الأكواد -----------------
class AdminAdSettingsPage extends StatefulWidget {
  const AdminAdSettingsPage({Key? key}) : super(key: key);
  @override
  State<AdminAdSettingsPage> createState() => _AdminAdSettingsPageState();
}
class _AdminAdSettingsPageState extends State<AdminAdSettingsPage> {
  bool _enableGlobalAds = true; 
  double _adsPerSession = 5.0;  
  double _breakDuration = 120.0; 
  
  // 👈 متغيرات حقول إدخال الأكواد
  final TextEditingController _interstitialCodeController = TextEditingController(text: 'ca-app-pub-3940256099942544/1033173712');
  final TextEditingController _rewardedCodeController = TextEditingController(text: 'ca-app-pub-3940256099942544/5224354917');

  void _saveAdSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث سياسة عرض الإعلانات وأكواد AdMob بنجاح! 📊'), backgroundColor: Colors.teal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحكم في الإعلانات (صفحة 10)'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. مفتاح الإيقاف الشامل
          Card(
            color: _enableGlobalAds ? Colors.teal[50] : Colors.red[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              title: const Text('تفعيل الإعلانات في التطبيق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: const Text('قم بإيقاف هذا المفتاح إذا شعرت بوجود زيارات وهمية مفرطة لحماية حسابك.'),
              value: _enableGlobalAds,
              activeColor: Colors.teal,
              onChanged: (val) => setState(() => _enableGlobalAds = val),
              secondary: Icon(Icons.security, color: _enableGlobalAds ? Colors.teal : Colors.red, size: 30),
            ),
          ),
          const SizedBox(height: 25),
          
          // 👈 2. قسم تعديل أكواد الإعلانات
          const Text('أكواد الوحدات الإعلانية (AdMob IDs)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          const Text('قم بتحديث الأكواد هنا لتتغير في هواتف المستخدمين فوراً دون الحاجة لتحديث التطبيق:', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 15),
          
          TextField(
            controller: _interstitialCodeController,
            decoration: const InputDecoration(
              labelText: 'كود الإعلان البيني (وقت الشحن)', 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.ad_units),
            ),
          ),
          const SizedBox(height: 15),
          
          TextField(
            controller: _rewardedCodeController,
            decoration: const InputDecoration(
              labelText: 'كود إعلان الفيديو بمكافأة (زر ضاعف أثرك)', 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.video_library),
            ),
          ),
          const SizedBox(height: 25),

          // 3. إعدادات الوقت والتكرار
          const Text('إعدادات التكرار الذكي (Auto-Loop)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),

          Text('عدد الإعلانات قبل تفعيل الاستراحة: ${_adsPerSession.toInt()} إعلانات', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _adsPerSession, min: 1, max: 10, divisions: 9, activeColor: Colors.teal, label: _adsPerSession.round().toString(),
            onChanged: (val) => setState(() => _adsPerSession = val),
          ),
          const SizedBox(height: 15),

          Text('مدة الاستراحة لتأمين العمليات: ${_breakDuration.toInt()} ثانية', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _breakDuration, min: 30, max: 300, divisions: 9, activeColor: Colors.teal, label: _breakDuration.round().toString(),
            onChanged: (val) => setState(() => _breakDuration = val),
          ),
          
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton.icon(
              onPressed: _saveAdSettings,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('حفظ إعدادات الإعلانات ونشرها', style: TextStyle(fontSize: 18, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800]),
            ),
          )
        ],
      ),
    );
  }
}
