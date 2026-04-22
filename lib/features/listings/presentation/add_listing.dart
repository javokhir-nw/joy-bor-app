import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';

class AddListingScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Map<String, dynamic>? editData;
  const AddListingScreen({super.key, this.onSuccess, this.editData});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _roomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedCategory = 'Kvartira';
  String _selectedPeriod = 'oylik';
  String _selectedCurrency = 'USD';
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  List<XFile> _images = [];
  bool _isLoading = false;
  bool _showMap = false;

  bool get _isEditMode => widget.editData != null;
  List<String> _existingImageUrls = [];

  final List<String> _categories = ['Kvartira', 'Uy', 'Xona', 'Ofis', 'Yer'];
  final List<String> _periods = ['kunlik', 'oylik', 'yillik'];
  final List<String> _currencies = ['USD', 'UZS'];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final d = widget.editData!;
      _titleController.text   = d['title']       ?? '';
      _descController.text    = d['description'] ?? '';
      _priceController.text   = '${d['price']    ?? ''}';
      _addressController.text = d['address']     ?? '';
      _roomsController.text   = '${d['rooms']    ?? ''}';
      _areaController.text    = '${d['area']     ?? ''}';
      _phoneController.text   = d['phone']       ?? '';
      _selectedCategory       = d['category']    ?? 'Kvartira';
      _selectedPeriod         = d['period']      ?? 'oylik';
      _selectedCurrency       = d['currency']    ?? 'USD';
      _existingImageUrls      = List<String>.from(d['images'] ?? []);

      if (d['location'] != null) {
        _selectedLocation = LatLng(
          d['location'].latitude,
          d['location'].longitude,
        );
        _showMap = true;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _roomsController.dispose();
    _areaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);
    if (images.isNotEmpty) {
      setState(() {
        _images = [..._images, ...images].take(8).toList();
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!kIsWeb) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
        _showMap = true;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );
    } catch (e) {
      setState(() {
        _selectedLocation = const LatLng(41.2995, 69.2401);
        _showMap = true;
      });
    }
  }

  Future<List<String>> _uploadImages(String listingId) async {
    final List<String> urls = [];
    // Edit modeda mavjud rasmlar sonidan keyin indeks boshlaydi
    final startIndex = _existingImageUrls.length;
    for (int i = 0; i < _images.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('listings/$listingId/image_${startIndex + i}.jpg');
      if (kIsWeb) {
        final bytes = await _images[i].readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(_images[i].path));
      }
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);
  try {
    final user = FirebaseAuth.instance.currentUser!;

    final docRef = _isEditMode
        ? FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.editData!['id'])
        : FirebaseFirestore.instance.collection('listings').doc();

    List<String> newUrls = [];
    if (_images.isNotEmpty) {
      newUrls = await _uploadImages(docRef.id);
    }

    final allImages = [..._existingImageUrls, ...newUrls];

    final dataMap = <String, dynamic>{
      'id': docRef.id,
      'uid': _isEditMode ? widget.editData!['uid'] : user.uid,
      'ownerName': _isEditMode
          ? widget.editData!['ownerName']
          : (user.displayName ?? ''),
      'phone': _phoneController.text.trim(),
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'category': _selectedCategory,
      'price': int.tryParse(_priceController.text.replaceAll(' ', '')) ?? 0,
      'currency': _selectedCurrency,
      'period': _selectedPeriod,
      'address': _addressController.text.trim(),
      'rooms': int.tryParse(_roomsController.text) ?? 0,
      'area': double.tryParse(_areaController.text) ?? 0,
      'images': allImages,
      'isActive': false, // admin tasdiqlamaguncha false
      'isFeatured': false,
      'views': _isEditMode ? (widget.editData!['views'] ?? 0) : 0,
      // --- Moderatsiya maydonlari ---
      'moderationStatus': 'pending',
      'riskLevel': '',
      'aiAnalysis': null,
      'approvedAt': null,
      'approvedBy': null,
      'rejectionReason': null,
      if (!_isEditMode) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (_selectedLocation != null) {
      dataMap['location'] = GeoPoint(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
    }

    if (_isEditMode) {
      await docRef.update(dataMap);
    } else {
      await docRef.set(dataMap);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditMode
            ? "E'lon yangilandi!"
            : "E'loningiz ko'rib chiqish uchun yuborildi!"),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onSuccess?.call();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Xato: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Widget _buildImageWidget(XFile img) {
    if (kIsWeb) {
      return Image.network(img.path,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (_, _, _) => Container(
                color: AppColors.surface,
                child: const Icon(Icons.broken_image,
                    color: AppColors.textSecondary),
              ));
    } else {
      return Image.file(File(img.path),
          fit: BoxFit.cover, width: 100, height: 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
        ),
        title: Text(
          _isEditMode ? "E'lonni tahrirlash" : "E'lon berish",
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Rasmlar ──
              const _SectionTitle(title: '📸 Rasmlar', subtitle: 'Max 8 ta'),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_rounded,
                                color: AppColors.primary, size: 32),
                            const SizedBox(height: 6),
                            Text("Rasm qo'sh",
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ),

                    // ── Mavjud rasmlar (edit mode) ──
                    ..._existingImageUrls.map((url) => Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0xFF1E293B),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Image.network(url,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100),
                            ),
                            Positioned(
                              top: 4,
                              right: 14,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _existingImageUrls.remove(url)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )),

                    // ── Yangi tanlangan rasmlar ──
                    ..._images.map((img) => Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0xFF1E293B),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: _buildImageWidget(img),
                            ),
                            Positioned(
                              top: 4,
                              right: 14,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _images.remove(img)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Kategoriya ──
              const _SectionTitle(title: '🏠 Kategoriya'),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categories.map((cat) {
                    final sel = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color:
                                  sel ? AppColors.primary : AppColors.divider),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 14,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Asosiy ma'lumotlar ──
              const _SectionTitle(title: "📝 Ma'lumotlar"),
              const SizedBox(height: 12),
              _buildField(
                controller: _titleController,
                label: 'Sarlavha *',
                hint: '3 xonali kvartira, Chilonzor',
                icon: Icons.title_rounded,
                validator: (v) => v!.isEmpty ? 'Sarlavha kiriting' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _descController,
                label: 'Tavsif',
                hint: "Uy haqida batafsil ma'lumot...",
                icon: Icons.description_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // ── Narx ──
              const _SectionTitle(title: '💰 Narx'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildField(
                      controller: _priceController,
                      label: 'Narx *',
                      hint: _selectedCurrency == 'USD' ? '500' : '6 500 000',
                      icon: Icons.attach_money_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Narx kiriting' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        dropdownColor: const Color(0xFF1E293B),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        items: _currencies
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCurrency = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        dropdownColor: const Color(0xFF1E293B),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        items: _periods
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedPeriod = v!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Parametrlar ──
              const _SectionTitle(title: '📐 Parametrlar'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _roomsController,
                      label: 'Xonalar',
                      hint: '3',
                      icon: Icons.meeting_room_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _areaController,
                      label: 'Maydon (m²)',
                      hint: '65',
                      icon: Icons.square_foot_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Aloqa ──
              const _SectionTitle(title: '📞 Aloqa'),
              const SizedBox(height: 12),
              _buildField(
                controller: _phoneController,
                label: 'Telefon raqam *',
                hint: '+998 90 123 45 67',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v!.isEmpty ? 'Telefon raqam kiriting' : null,
              ),
              const SizedBox(height: 24),

              // ── Lokatsiya ──
              const _SectionTitle(title: '📍 Lokatsiya'),
              const SizedBox(height: 12),
              _buildField(
                controller: _addressController,
                label: 'Manzil',
                hint: 'Toshkent, Chilonzor tumani...',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 20),
                label: Text(_selectedLocation == null
                    ? 'Xaritadan belgilash'
                    : '✅ Lokatsiya belgilandi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedLocation == null
                      ? const Color(0xFF1E293B)
                      : AppColors.primary.withValues(alpha: 0.2),
                  foregroundColor: _selectedLocation == null
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                  side: BorderSide(
                    color: _selectedLocation == null
                        ? AppColors.divider
                        : AppColors.primary,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (_showMap && _selectedLocation != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 220,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                          target: _selectedLocation!, zoom: 15),
                      onMapCreated: (c) => _mapController = c,
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: _selectedLocation!,
                          draggable: true,
                          onDragEnd: (pos) =>
                              setState(() => _selectedLocation = pos),
                        ),
                      },
                      onTap: (pos) =>
                          setState(() => _selectedLocation = pos),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // ── Submit ──
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _isEditMode ? "E'lonni saqlash" : "E'lonni joylash",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(subtitle!,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ],
    );
  }
}