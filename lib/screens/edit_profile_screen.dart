import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'theme_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> ngmUser;
  final Map<String, dynamic> profile;
  final VoidCallback onSaved;

  const EditProfileScreen({
    super.key,
    required this.ngmUser,
    required this.profile,
    required this.onSaved,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving    = false;
  bool _isUploading = false;
  File? _pickedImage;
  String? _uploadedUrl;

  late TextEditingController _fullNameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _districtCtrl;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.ngmUser['full_name'] ?? widget.profile['full_name'] ?? '');
    _usernameCtrl = TextEditingController(text: widget.ngmUser['username'] ?? '');
    _bioCtrl      = TextEditingController(text: widget.ngmUser['bio'] ?? '');
    _mobileCtrl   = TextEditingController(text: widget.ngmUser['mobile'] ?? widget.profile['mobile'] ?? '');
    _districtCtrl = TextEditingController(text: widget.profile['district'] ?? '');
    final dobStr  = widget.ngmUser['date_of_birth'] ?? widget.profile['date_of_birth'];
    if (dobStr != null) _dob = DateTime.tryParse(dobStr.toString());
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _mobileCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════
  //  PHOTO PICK + S3 UPLOAD
  // ══════════════════════════════════════════
  Future<void> _pickPhoto() async {
    final t = context.read<ThemeProvider>();
    // Show source chooser
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: t.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('Profile Photo', style: TextStyle(color: t.text1, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _sourceOption(Icons.camera_alt_rounded, 'Camera', () => Navigator.pop(context, ImageSource.camera), t),
                const SizedBox(height: 10),
                _sourceOption(Icons.photo_library_rounded, 'Gallery', () => Navigator.pop(context, ImageSource.gallery), t),
                const SizedBox(height: 10),
                if (widget.ngmUser['profile_picture_url'] != null)
                  _sourceOption(Icons.delete_outline, 'Remove Photo', () => Navigator.pop(context, null), t, isRed: true),
              ],
            ),
          ),
        ),
      ),
    );

    if (source == null) {
      // Remove photo tapped
      if (widget.ngmUser['profile_picture_url'] != null) {
        setState(() => _uploadedUrl = '');
      }
      return;
    }

    final picker = ImagePicker();
    // ✅ FIX: imageQuality converts HEIC→JPEG automatically via image_picker
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    // ✅ Always use JPEG — avoids HEIC/WEBP mime-type rejection
    final imageBytes = await picked.readAsBytes();

    setState(() {
      _pickedImage  = File(picked.path);
      _isUploading  = true;
    });

    try {
      final uid      = widget.ngmUser['user_id'] as String;
      // ✅ Always save as .jpg regardless of source format
      // ✅ Timestamp in filename = cache bust on every upload
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${uid}_${ts}.jpg';
      await Supabase.instance.client.storage
          .from('profile-pictures')
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final url = Supabase.instance.client.storage
          .from('profile-pictures')
          .getPublicUrl(fileName);

      setState(() {
        _uploadedUrl  = url;
        _isUploading  = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _sourceOption(IconData icon, String label, VoidCallback onTap, ThemeProvider t, {bool isRed = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Row(children: [
          Icon(icon, color: isRed ? Colors.red : t.brand, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isRed ? Colors.red : t.text1, fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  BIO BOTTOM SHEET POPUP
  // ══════════════════════════════════════════
  Future<void> _openBioEditor() async {
    final t   = context.read<ThemeProvider>();
    final tmp = TextEditingController(text: _bioCtrl.text);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: t.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Bio Edit', style: TextStyle(color: t.text1, fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          _bioCtrl.text = tmp.text;
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [t.brand, const Color(0xFF6B3FC6)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.surface2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.border),
                        ),
                        child: TextField(
                          controller: tmp,
                          autofocus: true,
                          maxLines: 5,
                          maxLength: 200,
                          style: TextStyle(color: t.text1, fontSize: 14, height: 1.5),
                          decoration: InputDecoration(
                            hintText: 'Tell about yourself...',
                            hintStyle: TextStyle(color: t.text2),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(14),
                            counterStyle: TextStyle(color: t.text2, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SAVE
  // ══════════════════════════════════════════
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final uid    = widget.ngmUser['user_id'] as String;
      final dobStr = _dob != null
          ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
          : null;

      final Map<String, dynamic> ngmUpdate = {
        'full_name':  _fullNameCtrl.text.trim(),
        'username':   _usernameCtrl.text.trim(),
        'bio':        _bioCtrl.text.trim(),
        'mobile':     _mobileCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        if (dobStr != null) 'date_of_birth': dobStr,
        if (_uploadedUrl != null && _uploadedUrl!.isNotEmpty) 'profile_picture_url': _uploadedUrl,
        if (_uploadedUrl == '') 'profile_picture_url': null,
      };

      final Map<String, dynamic> profileUpdate = {
        'full_name':  _fullNameCtrl.text.trim(),
        'mobile':     _mobileCtrl.text.trim(),
        'district':   _districtCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        if (dobStr != null) 'date_of_birth': dobStr,
      };

      await Future.wait([
        Supabase.instance.client.from('ngm_users').update(ngmUpdate).eq('user_id', uid),
        Supabase.instance.client.from('profiles').update(profileUpdate).eq('id', uid),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated ✓'), backgroundColor: Colors.green),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final t = context.read<ThemeProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: t.brand, surface: t.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: t.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(t),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatarSection(t),
                        const SizedBox(height: 24),
                        _sectionLabel('Personal Info', t),
                        _field('Full Name', _fullNameCtrl, Icons.person_outline, t, required: true),
                        _field('Username', _usernameCtrl, Icons.alternate_email, t, validator: (v) {
                          if (v == null || v.isEmpty) return 'Username required';
                          if (v.contains(' ')) return 'No spaces allowed';
                          return null;
                        }),
                        // ✅ Bio tap → popup
                        _bioField(t),
                        _field('Mobile', _mobileCtrl, Icons.phone_outlined, t, keyboardType: TextInputType.phone),
                        _dateField(t),
                        const SizedBox(height: 8),
                        _sectionLabel('KAPiLa Info', t),
                        _field('District', _districtCtrl, Icons.location_on_outlined, t),
                        _infoRow('Level',   widget.profile['current_level'] ?? '-',           Icons.star_outline, t),
                        _infoRow('Rank',    '#${widget.profile['current_rank'] ?? '-'}',       Icons.leaderboard_outlined, t),
                        _infoRow('Tests',   '${widget.profile['total_tests_taken'] ?? 0}',    Icons.quiz_outlined, t),
                        _infoRow('Credits', '${widget.profile['credits'] ?? 0}',              Icons.diamond_outlined, t),
                        const SizedBox(height: 32),
                        _saveButton(t),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeProvider t) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: t.glassBg, border: Border(bottom: BorderSide(color: t.border))),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
                  child: Icon(Icons.arrow_back_ios_rounded, color: t.text1, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Text('Edit Profile', style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [t.brand, const Color(0xFF6B3FC6)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(ThemeProvider t) {
    // ✅ Always use latest uploaded URL or existing, never stale cache
    final currentUrl = _uploadedUrl != null && _uploadedUrl!.isNotEmpty
        ? _uploadedUrl
        : _uploadedUrl == ''
            ? null
            : widget.ngmUser['profile_picture_url'] as String?;
    final name       = _fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text : 'U';

    return Center(
      child: Stack(
        children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.brand, width: 2),
              color: t.brand.withOpacity(0.15),
            ),
            child: ClipOval(
              child: _isUploading
                  ? Center(child: CircularProgressIndicator(color: t.brand, strokeWidth: 2))
                  : _pickedImage != null
                      ? Image.file(_pickedImage!, fit: BoxFit.cover)
                      : currentUrl != null && currentUrl.isNotEmpty
                          ? Image.network(currentUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarPlaceholder(name, t))
                          : _avatarPlaceholder(name, t),
            ),
          ),
          Positioned(
            right: 0, bottom: 0,
            child: GestureDetector(
              onTap: _isUploading ? null : _pickPhoto,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [t.brand, const Color(0xFF6B3FC6)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: t.bg, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(String name, ThemeProvider t) {
    return Center(
      child: Text(name[0].toUpperCase(),
          style: TextStyle(fontSize: 36, color: t.brand, fontWeight: FontWeight.bold)),
    );
  }

  Widget _sectionLabel(String label, ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: t.text1, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ✅ Bio field - tap to open popup
  Widget _bioField(ThemeProvider t) {
    return GestureDetector(
      onTap: _openBioEditor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.glassBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.glassBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: t.brand, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bio', style: TextStyle(color: t.text2, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        _bioCtrl.text.isEmpty ? 'Tell about yourself...' : _bioCtrl.text,
                        style: TextStyle(
                          color: _bioCtrl.text.isEmpty ? t.text2.withOpacity(0.5) : t.text1,
                          fontSize: 14, height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_rounded, color: t.text2, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, ThemeProvider t,
      {String? hint, int maxLines = 1, TextInputType? keyboardType, bool required = false,
       String? Function(String?)? validator}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: t.glassBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.glassBorder)),
          child: TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: t.text1, fontSize: 14),
            validator: validator ?? (required ? (v) => (v == null || v.isEmpty) ? '$label required' : null : null),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: TextStyle(color: t.text2, fontSize: 13),
              hintStyle: TextStyle(color: t.text2.withOpacity(0.5), fontSize: 13),
              prefixIcon: Icon(icon, color: t.brand, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(ThemeProvider t) {
    return GestureDetector(
      onTap: _pickDate,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: t.glassBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.glassBorder)),
            child: Row(children: [
              Icon(Icons.cake_outlined, color: t.brand, size: 18),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Date of Birth', style: TextStyle(color: t.text2, fontSize: 12)),
                Text(
                  _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Select date',
                  style: TextStyle(color: _dob != null ? t.text1 : t.text2.withOpacity(0.5), fontSize: 14),
                ),
              ]),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: t.text2, size: 14),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon, ThemeProvider t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: t.glassBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.glassBorder)),
          child: Row(children: [
            Icon(icon, color: t.brand, size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: t.text2, fontSize: 13)),
            const Spacer(),
            Text(value, style: TextStyle(color: t.text1, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _saveButton(ThemeProvider t) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _isSaving ? null : _save,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [t.brand, const Color(0xFF6B3FC6)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: t.brand.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Center(
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}