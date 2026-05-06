import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../distributor/distributor_home.dart';
import '../dispatch/dispatch_home.dart';
import '../production/production_home.dart';
import '../rawmaterial/rm_home.dart';
import '../owner/owner_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _loadingDistributors = true;
  String? _errorMsg;
  String? _selectedRole;
  List<User> _distributors = [];

  static const _staffRoleUsernames = {
    'Owner': 'owner',
    'Dispatch': 'dispatch',
    'Supervisor': 'supervisor',
    'Operator': 'operator',
  };

  Map<String, String> get _roleUsernames {
    final distributorOptions = {
      for (final distributor in _distributors)
        'Distributor - ${distributor.name}': distributor.username,
    };
    return {..._staffRoleUsernames, ...distributorOptions};
  }

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadDistributors();
  }

  Future<void> _loadDistributors() async {
    final distributors = await ApiService.getDistributors();
    if (!mounted) return;
    setState(() {
      _distributors = distributors;
      _loadingDistributors = false;
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (_selectedRole == null) {
      setState(() => _errorMsg = 'Please select an account.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMsg = 'Please enter your password.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final result = await ApiService.login(username, password);

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _loading = false;
        _errorMsg = 'Invalid password. Please try again.';
      });
      return;
    }

    await ApiService.saveToken(result['token']);

    final userData = result['user'];
    final user = User(
      id: userData['id'],
      name: userData['name'],
      mobile: userData['mobile'],
      role: _parseRole(userData['role']),
      username: userData['username'],
      password: '',
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _homeForRole(user)),
    );
  }

  UserRole _parseRole(String role) {
    switch (role) {
      case 'owner':
        return UserRole.owner;
      case 'dispatch':
        return UserRole.dispatch;
      case 'supervisor':
        return UserRole.supervisor;
      case 'operator':
        return UserRole.operator;
      case 'distributor':
        return UserRole.distributor;
      default:
        return UserRole.operator;
    }
  }

  Widget _homeForRole(User user) {
    switch (user.role) {
      case UserRole.owner:
        return const OwnerDashboard();
      case UserRole.dispatch:
        return const DispatchHome();
      case UserRole.supervisor:
        return const ProductionHome();
      case UserRole.operator:
        return const RMHome();
      case UserRole.distributor:
        return DistributorHome(user: user); // ✅ FIXED
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryNavy,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.factory_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Swami Polytech',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ERP & Dealer Platform',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Login Card ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select your account and enter password',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Role Dropdown
                    const Text(
                      'Select Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      hint: Text(
                        _loadingDistributors
                            ? 'Loading distributors...'
                            : 'Select your account',
                      ),
                      items: _roleUsernames.keys.map((role) {
                        return DropdownMenuItem(value: role, child: Text(role));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value;
                          _usernameCtrl.text = _roleUsernames[value]!;
                        });
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Password
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _loading ? null : _login(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppTheme.textSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),

                    if (_errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.lightRed,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 16,
                                color: AppTheme.dangerRed,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.dangerRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.borderGrey,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
