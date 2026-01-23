import 'dart:async';
import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../services/safety_tips_service.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  final SafetyTipsService _safetyTipsService = SafetyTipsService();

  List<SafetyCategory> categories = [];
  
  // ✅ Cache tips and measures data
  final Map<int, List<SafetyTip>> _cachedTips = {};
  final Map<int, List<PreventiveMeasure>> _cachedMeasures = {};
  final Map<int, bool> _loadingTips = {};
  final Map<int, bool> _loadingMeasures = {};
  
  StreamSubscription<List<SafetyCategory>>? _categorySubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadCategories();
  }

  void _loadCategories() {
    print('🟢 _loadCategories() called');
    
    _categorySubscription?.cancel();
    
    print('🎧 Starting to listen to category stream...');
    
    _categorySubscription = _safetyTipsService.getActiveCategories().listen(
      (loadedCategories) {
        print('🎯 Received ${loadedCategories.length} categories from stream');
        
        if (!mounted || loadedCategories.isEmpty) {
          print('⚠️ Skipping update: mounted=$mounted, empty=${loadedCategories.isEmpty}');
          return;
        }
        
        if (categories.length != loadedCategories.length) {
          print('🔄 Updating TabController: ${categories.length} -> ${loadedCategories.length}');
          
          setState(() {
            categories = loadedCategories;
            
            final oldIndex = _tabController.index;
            _tabController.dispose();
            
            _tabController = TabController(
              length: categories.length,
              vsync: this,
              initialIndex: oldIndex < categories.length ? oldIndex : 0,
            );
            
            // ✅ Add listener to load data when tab changes
            _tabController.addListener(_onTabChanged);
            
            // ✅ Load data for first tab
            if (categories.isNotEmpty) {
              _loadTabData(categories[0].id);
            }
            
            print('✅ TabController updated successfully');
          });
        }
      },
      onError: (error) {
        print('❌ Error in category stream: $error');
      },
    );
  }

  // ✅ Load data when tab changes
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return; // Only trigger on final tab
    
    final categoryId = categories[_tabController.index].id;
    _loadTabData(categoryId);
  }

  // ✅ Load data for specific category (only if not already cached)
  void _loadTabData(int categoryId) {
    // Load tips if not cached
    if (!_cachedTips.containsKey(categoryId) && _loadingTips[categoryId] != true) {
      _loadingTips[categoryId] = true;
      print('📥 Loading tips for category $categoryId');
      
      _safetyTipsService.getTipsForCategory(categoryId).first.then((tips) {
        if (mounted) {
          setState(() {
            _cachedTips[categoryId] = tips;
            _loadingTips[categoryId] = false;
          });
        }
      });
    }

    // Load measures if not cached
    if (!_cachedMeasures.containsKey(categoryId) && _loadingMeasures[categoryId] != true) {
      _loadingMeasures[categoryId] = true;
      print('📥 Loading measures for category $categoryId');
      
      _safetyTipsService.getPreventiveMeasuresForCategory(categoryId).first.then((measures) {
        if (mounted) {
          setState(() {
            _cachedMeasures[categoryId] = measures;
            _loadingMeasures[categoryId] = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safety Tips',
          style: TextStyle(color: Colors.white)
        ),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
        bottom: categories.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: categories.map((cat) => Tab(
                  icon: Icon(cat.iconData, size: 20),
                  text: cat.name,
                )).toList(),
              ),
      ),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: categories.map((cat) => 
                _buildCategoryContent(cat)
              ).toList(),
            ),
    );
  }

  Widget _buildCategoryContent(SafetyCategory category) {
    final tips = _cachedTips[category.id];
    final measures = _cachedMeasures[category.id];
    final isLoadingTips = _loadingTips[category.id] ?? false;
    final isLoadingMeasures = _loadingMeasures[category.id] ?? false;

    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: category.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      category.iconData,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      category.description.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Use cached data instead of StreamBuilder
            if (isLoadingTips)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (tips != null && tips.isNotEmpty)
              Column(
                children: tips.map((tip) => _buildColorCodedItem(
                  tip.range,
                  tip.level,
                  tip.descriptions,
                  tip.colorData,
                )).toList(),
              )
            else if (tips != null && tips.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No tips available for this category.'),
                ),
              ),

            const SizedBox(height: 16),

            // ✅ Use cached measures
            if (isLoadingMeasures)
              const SizedBox.shrink()
            else if (measures != null && measures.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PREVENTIVE MEASURES',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...measures.map((measure) => _buildNumberedItem(
                    measure.number,
                    measure.title,
                    measure.description,
                  )).toList(),
                  const SizedBox(height: 20),
                ],
              ),
          ],
        ),
      ),
    );
  }

    // ... rest of your widget methods stay the same
  

  Widget _buildColorCodedItem(
    String range,
    String level,
    List<String> descriptions,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical:  8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                range,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...descriptions.map((desc) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child:  Row(
                      crossAxisAlignment:  CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: color, fontSize: 16)),
                        Expanded(
                          child: Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedItem(String number, String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:  BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color:  Colors.green,
                shape: BoxShape. circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style:  const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}