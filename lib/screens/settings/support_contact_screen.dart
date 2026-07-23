import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Support the developer (Ko-fi) and a lightweight contact form. The form
/// posts directly to Web3Forms (a hosted form-relay service) rather than
/// mailto -- the tester's own email app/address is never involved unless
/// they choose to leave a reply email themselves.
class SupportContactScreen extends StatefulWidget {
  const SupportContactScreen({super.key});

  @override
  State<SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends State<SupportContactScreen> {
  static const _kofiUrl = 'https://ko-fi.com/towersys';

  static const _web3formsAccessKey = 'a4f36798-663f-491b-b4e6-2a27eaf75827';

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _replyEmailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _replyEmailController.dispose();
    super.dispose();
  }

  Future<void> _openKofi() async {
    final uri = Uri.parse(_kofiUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Ko-fi. Do you have a browser installed?')),
      );
    }
  }

  Future<void> _sendFeedback() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    final replyEmail = _replyEmailController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a message first.')),
      );
      return;
    }
    // replyto only sets the email header (invisible unless you hit Reply),
    // so also tack the email onto the visible message body -- otherwise it
    // looks like it silently vanished when reading the notification email.
    final fullMessage = replyEmail.isEmpty
        ? message
        : '$message\n\n---\nReply email: $replyEmail';

    setState(() => _sending = true);
    try {
      final response = await http.post(
        Uri.parse('https://api.web3forms.com/submit'),
        headers: {'Accept': 'application/json'},
        body: {
          'access_key': _web3formsAccessKey,
          'subject': subject.isEmpty ? 'SwitchBoard feedback' : subject,
          'message': fullMessage,
          if (replyEmail.isNotEmpty) 'replyto': replyEmail,
          'from_name': 'SwitchBoard tester',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        _subjectController.clear();
        _messageController.clear();
        _replyEmailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent -- thank you!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send (server said: ${response.statusCode}). Try again later.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Support the developer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Buy me a coffee on Ko-fi'),
            subtitle: const Text('If SwitchBoard has been useful to you'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openKofi,
          ),
        ),
        const SizedBox(height: 24),
        const Text('Contact the developer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Sent directly from the app -- your email app is never opened, '
          'and you don\'t need to share your address unless you want a reply.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subjectController,
          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Message',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _replyEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Your email (optional, only if you want a reply, recommended if reporting a bug or requeseting a feature)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _sending ? null : _sendFeedback,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_sending ? 'Sending...' : 'Send'),
          ),
        ),
      ],
    );
  }
}