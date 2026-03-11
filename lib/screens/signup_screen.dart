import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/image_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cnicController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  DateTime? _dateOfBirth;
  String? _studentCardFrontBase64;
  String? _studentCardBackBase64;
  String? _cnicFrontBase64;
  String? _cnicBackBase64;
  String? _licenseFrontBase64;
  String? _licenseBackBase64;
  bool _hasCar = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _cnicController.dispose();
    _studentIdController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final image = await ImageUtils.pickImage(source: source);
    if (image == null) return;

    final base64 = await ImageUtils.imageToBase64(image);
    if (base64 == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
      }
      return;
    }

    setState(() {
      switch (type) {
        case 'studentCardFront':
          _studentCardFrontBase64 = base64;
          break;
        case 'studentCardBack':
          _studentCardBackBase64 = base64;
          break;
        case 'cnicFront':
          _cnicFrontBase64 = base64;
          break;
        case 'cnicBack':
          _cnicBackBase64 = base64;
          break;
        case 'licenseFront':
          _licenseFrontBase64 = base64;
          break;
        case 'licenseBack':
          _licenseBackBase64 = base64;
          break;
      }
    });
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF49977a),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  // Validation helper methods
  void _showValidationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  bool _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      _showValidationError('Email is required');
      return false;
    }
    if (!value.contains('@') || !value.contains('.')) {
      _showValidationError('Make sure the email is valid and contains @ and . (e.g., user@example.com)');
      return false;
    }
    // Additional check: @ should come before .
    final atIndex = value.indexOf('@');
    final dotIndex = value.lastIndexOf('.');
    if (atIndex == -1 || dotIndex == -1 || atIndex >= dotIndex || dotIndex == value.length - 1) {
      _showValidationError('Make sure the email is valid and contains @ and . (e.g., user@example.com)');
      return false;
    }
    return true;
  }

  bool _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      _showValidationError('Phone number is required');
      return false;
    }
    // The value should be just digits (prefixText handles +92 display)
    // But we need to check if it includes +92 or not
    String phoneNumber;
    if (value.startsWith('+92')) {
      phoneNumber = value.substring(3); // Remove +92
    } else {
      phoneNumber = value; // User typed digits only
    }
    
    if (phoneNumber.length != 10) {
      _showValidationError('Make sure the phone number has exactly 10 digits after +92 (e.g., +923001234567)');
      return false;
    }
    if (!RegExp(r'^\d+$').hasMatch(phoneNumber)) {
      _showValidationError('Phone number can only contain digits after +92');
      return false;
    }
    return true;
  }

  bool _validateCNIC(String? value) {
    if (value == null || value.isEmpty) {
      _showValidationError('CNIC number is required');
      return false;
    }
    // Check format: XXXXX-XXXXXXX-X (15 characters total)
    if (value.length != 15) {
      _showValidationError('Make sure the CNIC is in the format XXXXX-XXXXXXX-X (15 characters total)');
      return false;
    }
    // Check dashes are in correct positions
    if (value[5] != '-' || value[13] != '-') {
      _showValidationError('Make sure the CNIC is in the format XXXXX-XXXXXXX-X (dashes after 5 digits and before last digit)');
      return false;
    }
    // Check all other characters are digits
    final digitsOnly = value.replaceAll('-', '');
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly) || digitsOnly.length != 13) {
      _showValidationError('CNIC can only contain digits (no alphabets). Format: XXXXX-XXXXXXX-X');
      return false;
    }
    return true;
  }

  bool _validateDateOfBirth() {
    if (_dateOfBirth == null) {
      _showValidationError('Date of birth is required');
      return false;
    }
    final today = DateTime.now();
    final age = today.year - _dateOfBirth!.year;
    final monthDiff = today.month - _dateOfBirth!.month;
    final dayDiff = today.day - _dateOfBirth!.day;
    
    final actualAge = (monthDiff < 0 || (monthDiff == 0 && dayDiff < 0)) ? age - 1 : age;
    
    if (actualAge < 18) {
      _showValidationError('You must be at least 18 years old to register');
      return false;
    }
    return true;
  }

  bool _validateStudentId(String? value) {
    if (value == null || value.isEmpty) {
      _showValidationError('Student ID is required');
      return false;
    }
    if (value.length != 6) {
      _showValidationError('Make sure the Student ID is exactly 6 digits (e.g., 123456)');
      return false;
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      _showValidationError('Student ID can only contain numbers (no alphabets). Format: 123456');
      return false;
    }
    return true;
  }


  Future<void> _handleSignup() async {
    // Validate all fields with custom validators
    if (!_validateEmail(_emailController.text.trim())) return;
    if (!_validatePhone(_phoneController.text.trim())) return;
    if (!_validateCNIC(_cnicController.text.trim())) return;
    if (!_validateDateOfBirth()) return;
    if (!_validateStudentId(_studentIdController.text.trim())) return;
    
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to Terms and Conditions')),
      );
      return;
    }
    if (_studentCardFrontBase64 == null || _studentCardBackBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload student card (front and back)')),
      );
      return;
    }

    if (_hasCar && (_licenseFrontBase64 == null || _licenseBackBase64 == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload driving license (front and back)')),
      );
      return;
    }

    // Duplicate studentId/CNIC check is done inside AuthService after auth (so Firestore rules allow it)
    setState(() => _isLoading = true);

    final userData = UserModel(
      uid: '', // Will be set after auth creation
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: '+92${_phoneController.text.trim()}', // Add +92 prefix to stored value
      cnic: _cnicController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      studentId: _studentIdController.text.trim(),
      studentCardFront: _studentCardFrontBase64,
      studentCardBack: _studentCardBackBase64,
      cnicFront: _cnicFrontBase64,
      cnicBack: _cnicBackBase64,
      licenseFront: _licenseFrontBase64,
      licenseBack: _licenseBackBase64,
      hasCar: _hasCar,
      createdAt: DateTime.now(),
    );

    debugPrint('Signup: Creating user with hasCar: $_hasCar, licenseFront: ${_licenseFrontBase64 != null ? "present" : "null"}, licenseBack: ${_licenseBackBase64 != null ? "present" : "null"}');

    final result = await _authService.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      userData: userData,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // Show success message and redirect to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please wait for admin verification before logging in.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        // Redirect to login screen after signup
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Signup failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDocumentUploadButton(String label, String type, String? base64) {
    return InkWell(
      onTap: () => _pickImage(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: base64 != null ? const Color(0xFF49977a) : Colors.grey.shade300,
            width: base64 != null ? 2 : 1,
            style: base64 != null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: base64 != null ? const Color(0xFF49977a) : Colors.grey.shade700,
                fontWeight: base64 != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Icon(
              base64 != null ? Icons.check_circle : Icons.upload_file,
              color: base64 != null ? const Color(0xFF49977a) : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 32),
                // First Name
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!_validateEmail(value)) return null; // Error shown in validation method
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10), // Only 10 digits (prefixText shows +92)
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    prefixText: '+92',
                    hintText: '3001234567',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    // Value is just digits, prefixText shows +92
                    if (!_validatePhone(value)) return null; // Error shown in validation method
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // CNIC
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                    LengthLimitingTextInputFormatter(15),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;
                      // Auto-format CNIC: XXXXX-XXXXXXX-X
                      if (text.length <= 5) {
                        return newValue;
                      } else if (text.length == 6 && !text.contains('-')) {
                        // Add first dash after 5 digits
                        return TextEditingValue(
                          text: '${text.substring(0, 5)}-${text.substring(5)}',
                          selection: TextSelection.collapsed(offset: 7),
                        );
                      } else if (text.length > 6 && text.length <= 13 && text[5] != '-') {
                        // Ensure first dash is present
                        return TextEditingValue(
                          text: '${text.substring(0, 5)}-${text.substring(5)}',
                          selection: TextSelection.collapsed(offset: text.length + 1),
                        );
                      } else if (text.length == 14 && text[13] != '-') {
                        // Add second dash before last digit
                        return TextEditingValue(
                          text: '${text.substring(0, 13)}-${text.substring(13)}',
                          selection: TextSelection.collapsed(offset: 15),
                        );
                      }
                      return newValue;
                    }),
                  ],
                  decoration: InputDecoration(
                    labelText: 'CNIC Number',
                    hintText: '35202-1234567-1',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!_validateCNIC(value)) return null; // Error shown in validation method
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Date of Birth
                InkWell(
                  onTap: _selectDateOfBirth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dateOfBirth == null
                                ? 'Date of Birth (DD / MM / YYYY)'
                                : DateFormat('dd / MM / yyyy').format(_dateOfBirth!),
                            style: TextStyle(
                              color: _dateOfBirth == null
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Student ID
                TextFormField(
                  controller: _studentIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Student ID / Roll Number',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!_validateStudentId(value)) return null; // Error shown in validation method
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Upload documents section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload documents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDocumentUploadButton(
                        'Student Card - Front',
                        'studentCardFront',
                        _studentCardFrontBase64,
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentUploadButton(
                        'Student Card - Back',
                        'studentCardBack',
                        _studentCardBackBase64,
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentUploadButton(
                        'CNIC - Front (optional)',
                        'cnicFront',
                        _cnicFrontBase64,
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentUploadButton(
                        'CNIC - Back (optional)',
                        'cnicBack',
                        _cnicBackBase64,
                      ),
                      const SizedBox(height: 24),
                      // Car ownership checkbox
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _hasCar,
                                  onChanged: (value) {
                                    setState(() {
                                      _hasCar = value ?? false;
                                      if (!_hasCar) {
                                        // Clear license data if unchecked
                                        _licenseFrontBase64 = null;
                                        _licenseBackBase64 = null;
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF49977a),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Do you have a car?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_hasCar) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Upload Driving License',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF49977a),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDocumentUploadButton(
                                'License - Front',
                                'licenseFront',
                                _licenseFrontBase64,
                              ),
                              const SizedBox(height: 12),
                              _buildDocumentUploadButton(
                                'License - Back',
                                'licenseBack',
                                _licenseBackBase64,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Only users with cars can post as drivers',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Terms checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) =>
                          setState(() => _agreeToTerms = value ?? false),
                      activeColor: const Color(0xFF49977a),
                    ),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black87),
                          children: [
                            TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF49977a),
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF49977a),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF49977a),
                          side: const BorderSide(color: Color(0xFF49977a)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF49977a),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

