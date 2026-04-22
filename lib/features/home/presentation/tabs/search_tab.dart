import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/listing_card.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _searchController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _roomsController = TextEditingController();

  String _category = 'Barchasi';
  String _currency = 'USD';
  int _rooms = 0;
  bool _showFilters = false;
  String _query = '';

  static const _categories = ['Barchasi', 'Kvartira', 'Uy', 'Xona', 'Ofis', 'Yer'];

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _stream {
  Query q = FirebaseFirestore.instance
      .collection('listings')
      .where('isActive', isEqualTo: true);

  if (_category != 'Barchasi') {
    q = q.where('category', isEqualTo: _category);
  }

  // rooms olib tashlandi ✅
  return q.orderBy('createdAt', descending: true).snapshots();
}

  void _clear() => setState(() {
    _category = 'Barchasi';
    _currency = 'USD';
    _rooms = 0;
    _query = '';
    _searchController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    _roomsController.clear();
  });

List<QueryDocumentSnapshot> _filter(List<QueryDocumentSnapshot> docs) {
  // Matn filter
  if (_query.isNotEmpty) {
    docs = docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final title = (d['title'] ?? '').toString().toLowerCase();
      final address = (d['address'] ?? '').toString().toLowerCase();
      return title.contains(_query) || address.contains(_query);
    }).toList();
  }

  // Narx filter
  final min = double.tryParse(_minPriceController.text);
  final max = double.tryParse(_maxPriceController.text);
  if (min != null || max != null) {
    docs = docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final price = (d['price'] ?? 0).toDouble();
      final cur = (d['currency'] ?? 'USD').toString();

      final converted = cur == _currency
          ? price
          : cur == 'USD'
              ? price * kRate
              : price / kRate;

      if (min != null && converted < min) return false;
      if (max != null && converted > max) return false;
      return true;
    }).toList();
  }

  // Xonalar filter — client side ✅
  if (_rooms > 0) {
    docs = docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return (d['rooms'] ?? 0) == _rooms;
    }).toList();
  }

  return docs;
}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _showFilters
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _buildFilters(),
        ),
        Container(height: 1, color: AppColors.divider),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _searchController,
              hint: 'Sarlavha yoki manzil...',
              prefix: const Icon(Icons.search_rounded,
                  color: Color(0xFF64748B), size: 20),
              suffix: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(Icons.close,
                          color: Color(0xFF64748B), size: 18),
                    )
                  : null,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _showFilters
                    ? AppColors.primary
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.tune_rounded,
                  color: _showFilters ? Colors.white : const Color(0xFF64748B),
                  size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Kategoriya
          const _Label('KATEGORIYA'),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          color: sel ? Colors.white : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Narx
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Label('NARX'),
              _CurrencyToggle(
                selected: _currency,
                onChanged: (v) => setState(() => _currency = v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Kurs: 1 USD = ${formatPrice(kRate)} UZS',
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _minPriceController,
                  hint: 'Min',
                  keyboardType: TextInputType.number,
                  prefix: Text(_currency == 'USD' ? '\$' : '₩',
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                    width: 14, height: 1.5,
                    color: const Color(0xFF334155)),
              ),
              Expanded(
                child: AppTextField(
                  controller: _maxPriceController,
                  hint: 'Max',
                  keyboardType: TextInputType.number,
                  prefix: Text(_currency == 'USD' ? '\$' : '₩',
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Xonalar
          const _Label('XONALAR SONI'),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            child: AppTextField(
              controller: _roomsController,
              hint: 'Masalan: 2',
              keyboardType: TextInputType.number,
              prefix: const Text('🛏',
                  style: TextStyle(fontSize: 14)),
              onChanged: (v) =>
                  setState(() => _rooms = int.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(height: 14),

          // Tozalash
          GestureDetector(
            onTap: _clear,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded,
                    size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Text('Filterlarni tozalash',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Xato: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error)));
        }

        final docs = _filter(snapshot.data?.docs ?? []);

        if (docs.isEmpty) return _buildEmpty();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) =>
              ListingCard(data: docs[i].data() as Map<String, dynamic>),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: Color(0xFF1E293B), shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded,
                size: 36, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          const Text('Natija topilmadi',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text("Boshqa kalit so'z yoki filter sinab ko'ring",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 16),
          TextButton(
              onPressed: _clear,
              child: const Text('Tozalash',
                  style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }
}

// ── Kichik widgetlar ──────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8));
}

class _CurrencyToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _CurrencyToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['USD', 'UZS'].map((cur) {
          final sel = selected == cur;
          return GestureDetector(
            onTap: () => onChanged(cur),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(cur,
                  style: TextStyle(
                    color: sel ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        sel ? FontWeight.w600 : FontWeight.w400,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}