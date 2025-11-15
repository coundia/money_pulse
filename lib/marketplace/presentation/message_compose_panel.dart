// Drawer: composer le message avant envoi (typeOrder="MESSAGE")

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import '../domain/entities/marketplace_item.dart';

// API
import 'package:jaayko/onboarding/presentation/providers/access_session_provider.dart';
import 'package:jaayko/marketplace/domain/entities/order_command_request.dart';
import 'package:jaayko/marketplace/infrastructure/order_command_repo_provider.dart';

class MessageComposePanel extends ConsumerStatefulWidget {
  final MarketplaceItem item;
  final String baseUri;
  const MessageComposePanel({
    super.key,
    required this.item,
    required this.baseUri,
  });

  static const double suggestedWidthFraction = 0.62;
  static const double suggestedHeightFraction = 0.50;

  @override
  ConsumerState<MessageComposePanel> createState() =>
      _MessageComposePanelState();
}

class _MessageComposePanelState extends ConsumerState<MessageComposePanel> {
  final _formKey = GlobalKey<FormState>();
  final _identCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final grant = ref.read(accessSessionProvider);
    final prefIdent = (grant?.phone?.trim().isNotEmpty == true)
        ? grant!.phone!.trim()
        : (grant?.username?.trim() ?? '');
    _identCtrl.text = prefIdent;
    _messageCtrl.text =
        'Bonjour, je suis intéressé par "${widget.item.name}" '
        '.';
  }

  @override
  void dispose() {
    _identCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sending) return;

    final grant = ref.read(accessSessionProvider);

    final payload = OrderCommandRequest(
      productId: widget.item.id,
      userId: grant?.id,
      identifiant: _identCtrl.text.trim(),
      telephone: grant?.phone,
      mail: grant?.email,
      ville: null,
      remoteId: null,
      localId: null,
      status: null,
      buyerName: grant?.username,
      address: null,
      notes: null,
      message: _messageCtrl.text.trim(),
      typeOrder: 'MESSAGE',
      paymentMethod: 'NA',
      deliveryMethod: 'NA',
      amountCents: widget.item.defaultPrice,
      quantity: 1,
      dateCommand: DateTime.now().toUtc(),
    );

    debugPrint(
      '[MessageComposePanel] about to send MESSAGE payload=${payload.toJson()}',
    );

    setState(() => _sending = true);
    try {
      await ref.read(orderCommandRepoProvider(widget.baseUri)).send(payload);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message enregistré, nous vous recontactons.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec enregistrement du message: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: AppBar(
                elevation: 0,
                centerTitle: false,
                titleSpacing: 12,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message au vendeur',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TextFormField(
                    controller: _identCtrl,
                    enabled: !_sending,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone ou email',
                      hintText: 'Téléphone ou email',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Téléphone ou email requis'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageCtrl,
                    enabled: !_sending,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Votre message…',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Message requis'
                        : null,
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Envoi…' : 'Envoyer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
