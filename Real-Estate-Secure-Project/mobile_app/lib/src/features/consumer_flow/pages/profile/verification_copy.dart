import '../../consumer_models.dart';

class ConsumerVerificationRoleCopy {
  const ConsumerVerificationRoleCopy({
    required this.role,
    required this.roleLabel,
    required this.pendingBody,
    required this.approvedBody,
    required this.startSummary,
    required this.emailPendingDescription,
    required this.phonePendingDescription,
    required this.readyChecklist,
    required this.verifiedChecklist,
  });

  final String role;
  final String roleLabel;
  final String pendingBody;
  final String approvedBody;
  final String startSummary;
  final String emailPendingDescription;
  final String phonePendingDescription;
  final List<String> readyChecklist;
  final List<String> verifiedChecklist;
}

ConsumerVerificationRoleCopy verificationCopyForRole(String role) {
  switch (normalizeConsumerRole(role)) {
    case 'seller':
      return const ConsumerVerificationRoleCopy(
        role: 'seller',
        roleLabel: 'Seller',
        pendingBody:
            'Confirm your identity to publish listings, share land files, and move sales forward.',
        approvedBody:
            'Your seller profile is ready for listing, review, and closing.',
        startSummary:
            'Start your identity check before you publish or submit listing files.',
        emailPendingDescription:
            'Verify this email so buyer and listing updates always reach you.',
        phonePendingDescription:
            'Verify this number so listing and closing updates reach you fast.',
        readyChecklist: [
          'Use a valid legal ID.',
          'Keep your phone and email nearby during the check.',
        ],
        verifiedChecklist: [
          'Your seller profile is ready for listings and buyer conversations.',
          'Keep your email and phone current.',
        ],
      );
    case 'lawyer':
      return const ConsumerVerificationRoleCopy(
        role: 'lawyer',
        roleLabel: 'Lawyer',
        pendingBody:
            'Confirm your identity to open legal files and work with clients through a trusted profile.',
        approvedBody:
            'Your legal profile is ready for client work and file review.',
        startSummary:
            'Start your identity check before you manage legal files in the app.',
        emailPendingDescription:
            'Verify this email so clients and file updates reach you reliably.',
        phonePendingDescription:
            'Verify this number so urgent file and client updates reach you quickly.',
        readyChecklist: [
          'Use a valid legal ID.',
          'Keep your contact details close during the check.',
        ],
        verifiedChecklist: [
          'Your legal profile is ready for client-facing work.',
          'Keep your contact details current.',
        ],
      );
    case 'notary':
      return const ConsumerVerificationRoleCopy(
        role: 'notary',
        roleLabel: 'Notary',
        pendingBody:
            'Confirm your identity to handle signings, closing steps, and trusted file handoffs.',
        approvedBody:
            'Your notary profile is ready for signings and closing work.',
        startSummary:
            'Start your identity check before you manage signings or closing steps in the app.',
        emailPendingDescription:
            'Verify this email so signing and file updates reach you reliably.',
        phonePendingDescription:
            'Verify this number so closing updates reach you without delay.',
        readyChecklist: [
          'Use a valid legal ID.',
          'Keep your phone and email nearby during the check.',
        ],
        verifiedChecklist: [
          'Your notary profile is ready for signings and closing handoffs.',
          'Keep your contact details current.',
        ],
      );
    default:
      return const ConsumerVerificationRoleCopy(
        role: 'buyer',
        roleLabel: 'Buyer',
        pendingBody:
            'Confirm your identity to unlock trusted enquiries, offers, and purchase steps.',
        approvedBody:
            'Your buyer profile is ready for trusted enquiries and next steps.',
        startSummary:
            'Start your identity check before you move deeper into offers and closing steps.',
        emailPendingDescription:
            'Verify this email so offer and property updates reach you reliably.',
        phonePendingDescription:
            'Verify this number so time-sensitive closing updates reach you quickly.',
        readyChecklist: [
          'Use a valid legal ID.',
          'Keep your phone and email nearby during the check.',
        ],
        verifiedChecklist: [
          'Your buyer profile is ready for verified enquiries and offers.',
          'Keep your email and phone current.',
        ],
      );
  }
}
