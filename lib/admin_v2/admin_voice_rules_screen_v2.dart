import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_layout.dart';

class AdminVoiceRulesScreenV2 extends StatefulWidget {
  const AdminVoiceRulesScreenV2({super.key});

  @override
  State<AdminVoiceRulesScreenV2> createState() => _AdminVoiceRulesScreenState();
}

class _AdminVoiceRulesScreenState extends State<AdminVoiceRulesScreenV2> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _rules = [];
  Map<String, dynamic>? _selectedRule;

  String _languageFilter = 'Toutes';
  String _typeFilter = 'Tous';
  String _statusFilter = 'Tous';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await supabase
          .from('search_voice_rules')
          .select('''
            id,
            is_active,
            language,
            rule_type,
            value,
            display_order,
            notes,
            created_at,
            updated_at
          ''')
          .order('language', ascending: true)
          .order('rule_type', ascending: true)
          .order('display_order', ascending: true)
          .order('value', ascending: true);

      final rules = List<Map<String, dynamic>>.from(response);

      setState(() {
        _rules = rules;
        _selectedRule = rules.isNotEmpty ? rules.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement : $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredRules() {
    final query = _searchQuery.trim().toLowerCase();

    return _rules.where((rule) {
      final language = (rule['language'] ?? '').toString();
      final type = (rule['rule_type'] ?? '').toString();
      final isActive = rule['is_active'] == true;
      final value = (rule['value'] ?? '').toString().toLowerCase();
      final notes = (rule['notes'] ?? '').toString().toLowerCase();

      final matchesLanguage =
          _languageFilter == 'Toutes' || language == _languageFilter;
      final matchesType =
          _typeFilter == 'Tous' || type == _typeFilter;
      final matchesStatus =
          _statusFilter == 'Tous' ||
          (_statusFilter == 'Actives' && isActive) ||
          (_statusFilter == 'Inactives' && !isActive);

      final matchesSearch =
          query.isEmpty || value.contains(query) || notes.contains(query);

      return matchesLanguage &&
          matchesType &&
          matchesStatus &&
          matchesSearch;
    }).toList();
  }

  Future<void> _toggleActive(Map<String, dynamic> rule) async {
    try {
      await supabase
          .from('search_voice_rules')
          .update({
            'is_active': !(rule['is_active'] == true),
          })
          .eq('id', rule['id']);

      await _loadRules();

      final refreshed = _rules.where((r) => r['id'] == rule['id']).toList();
      if (refreshed.isNotEmpty) {
        setState(() {
          _selectedRule = refreshed.first;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _deleteRule(Map<String, dynamic> rule) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer la règle ?'),
            content: Text(
              'Cette action supprimera définitivement la règle "${rule['value']}".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await supabase
          .from('search_voice_rules')
          .delete()
          .eq('id', rule['id']);

      await _loadRules();

      if (_rules.isNotEmpty) {
        setState(() {
          _selectedRule = _rules.first;
        });
      } else {
        setState(() {
          _selectedRule = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  void _openRuleDialog({Map<String, dynamic>? rule}) {
    final isEdit = rule != null;

    final valueController = TextEditingController(
      text: isEdit ? (rule['value'] ?? '').toString() : '',
    );
    final notesController = TextEditingController(
      text: isEdit ? (rule['notes'] ?? '').toString() : '',
    );
    final orderController = TextEditingController(
      text: isEdit ? (rule['display_order'] ?? 100).toString() : '100',
    );

    String selectedLanguage =
        isEdit ? (rule['language'] ?? 'fr').toString() : 'fr';
    String selectedRuleType =
        isEdit ? (rule['rule_type'] ?? 'useless_phrase').toString() : 'useless_phrase';
    bool isActive =
        isEdit ? rule['is_active'] == true : true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Modifier la règle' : 'Ajouter une règle'),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Langue',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'fr', child: Text('FR')),
                          DropdownMenuItem(value: 'en', child: Text('EN')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedLanguage = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRuleType,
                        decoration: const InputDecoration(
                          labelText: 'Type de règle',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'useless_phrase',
                            child: Text('useless_phrase'),
                          ),
                          DropdownMenuItem(
                            value: 'stop_word',
                            child: Text('stop_word'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedRuleType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: valueController,
                        decoration: const InputDecoration(
                          labelText: 'Valeur',
                          hintText: 'Ex : trouve moi / une / the',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Display order',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Règle active'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogContext);

                    final value = valueController.text.trim();
                    final notes = notesController.text.trim();
                    final displayOrder =
                        int.tryParse(orderController.text.trim()) ?? 100;

                    if (value.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('La valeur ne peut pas être vide.'),
                        ),
                      );
                      return;
                    }

                    try {
                      if (isEdit) {
                        await supabase
                            .from('search_voice_rules')
                            .update({
                              'language': selectedLanguage,
                              'rule_type': selectedRuleType,
                              'value': value,
                              'display_order': displayOrder,
                              'notes': notes.isEmpty ? null : notes,
                              'is_active': isActive,
                            })
                            .eq('id', rule['id']);
                      } else {
                        await supabase
                            .from('search_voice_rules')
                            .insert({
                              'language': selectedLanguage,
                              'rule_type': selectedRuleType,
                              'value': value,
                              'display_order': displayOrder,
                              'notes': notes.isEmpty ? null : notes,
                              'is_active': isActive,
                            });
                      }

                      if (!mounted) return;

                      navigator.pop();

                      await _loadRules();

                      final refreshed = _rules.where(
                        (r) =>
                            r['value'] == value &&
                            r['language'] == selectedLanguage &&
                            r['rule_type'] == selectedRuleType,
                      ).toList();

                      if (refreshed.isNotEmpty) {
                        setState(() {
                          _selectedRule = refreshed.first;
                        });
                      }

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Règle mise à jour avec succès.'
                                : 'Règle ajoutée avec succès.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Erreur : $e')),
                      );
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLeftPanel(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error!),
      );
    }

    final visibleRules = _filteredRules();
    final activeCount = _rules.where((r) => r['is_active'] == true).length;
    final inactiveCount = _rules.length - activeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Règles vocales',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _loadRules,
                tooltip: 'Rafraîchir',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Total ${_rules.length}')),
              Chip(label: Text('Actives $activeCount')),
              Chip(label: Text('Inactives $inactiveCount')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openRuleDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une règle'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Rechercher une règle',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: DropdownButtonFormField<String>(
            initialValue: _languageFilter,
            decoration: const InputDecoration(
              labelText: 'Langue',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Toutes', child: Text('Toutes')),
              DropdownMenuItem(value: 'fr', child: Text('FR')),
              DropdownMenuItem(value: 'en', child: Text('EN')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _languageFilter = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: DropdownButtonFormField<String>(
            initialValue: _typeFilter,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Tous', child: Text('Tous')),
              DropdownMenuItem(
                value: 'useless_phrase',
                child: Text('useless_phrase'),
              ),
              DropdownMenuItem(
                value: 'stop_word',
                child: Text('stop_word'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _typeFilter = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Statut',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Tous', child: Text('Tous')),
              DropdownMenuItem(value: 'Actives', child: Text('Actives')),
              DropdownMenuItem(value: 'Inactives', child: Text('Inactives')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _statusFilter = value;
              });
            },
          ),
        ),
        const Divider(height: 1),
        if (visibleRules.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Aucune règle trouvée.'),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: visibleRules.length,
              itemBuilder: (context, index) {
                final rule = visibleRules[index];
                final isSelected = _selectedRule?['id'] == rule['id'];

                final value = (rule['value'] ?? '').toString();
                final subtitle =
                    '${rule['language']} • ${rule['rule_type']} • ordre ${rule['display_order'] ?? 100}';

                return Material(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  child: ListTile(
                    selected: isSelected,
                    title: Text(value),
                    subtitle: Text(subtitle),
                    trailing: Chip(
                      label: Text(
                        rule['is_active'] == true ? 'Active' : 'Inactive',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor:
                          rule['is_active'] == true ? Colors.green : Colors.grey,
                    ),
                    onTap: () {
                      setState(() {
                        _selectedRule = rule;
                      });
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRightPanel(ThemeData theme) {
    final rule = _selectedRule;

    if (rule == null) {
      return const Center(
        child: Text('Aucune règle sélectionnée.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openRuleDialog(rule: rule),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Modifier'),
              ),
              OutlinedButton.icon(
                onPressed: () => _toggleActive(rule),
                icon: Icon(
                  rule['is_active'] == true
                      ? Icons.visibility_off
                      : Icons.visibility,
                  size: 18,
                ),
                label: Text(
                  rule['is_active'] == true ? 'Désactiver' : 'Activer',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _deleteRule(rule),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer'),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (rule['value'] ?? '—').toString(),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Langue ${rule['language'] ?? '—'}')),
                    Chip(label: Text('Type ${rule['rule_type'] ?? '—'}')),
                    Chip(
                      label: Text(
                        rule['is_active'] == true ? 'Active' : 'Inactive',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor:
                          rule['is_active'] == true ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Détail de la règle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(label: 'Valeur', value: rule['value']),
              _InfoLine(label: 'Langue', value: rule['language']),
              _InfoLine(label: 'Type', value: rule['rule_type']),
              _InfoLine(label: 'Display order', value: rule['display_order']),
              _InfoLine(label: 'Notes', value: rule['notes']),
              _InfoLine(label: 'Créée le', value: rule['created_at']),
              _InfoLine(label: 'Mise à jour le', value: rule['updated_at']),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return AdminLayout(
      title: 'Voice Rules',
      child: isWide
          ? Row(
              children: [
                SizedBox(
                  width: 380,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: _buildLeftPanel(theme),
                  ),
                ),
                Expanded(
                  child: _buildRightPanel(theme),
                ),
              ],
            )
          : Column(
              children: [
                SizedBox(
                  height: 420,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: _buildLeftPanel(theme),
                  ),
                ),
                Expanded(
                  child: _buildRightPanel(theme),
                ),
              ],
            ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final dynamic value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  String _display(dynamic value) {
    if (value == null) return '—';
    final text = value.toString().trim();
    if (text.isEmpty) return '—';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(_display(value)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}