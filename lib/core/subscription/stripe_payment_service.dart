import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../network/api_exception.dart';

/// Résultat de la présentation de la PaymentSheet Stripe dans l'application Flutter.
enum PaymentSheetOutcome {
  /// L'utilisateur a validé son paiement par carte dans l'application.
  /// (La confirmation finale de l'abonnement est attendue côté serveur via Stripe.)
  submitted,

  /// L'utilisateur a fermé la feuille de paiement sans payer.
  canceled,
}

/// Service d'encapsulation du SDK natif `flutter_stripe` (PaymentSheet).
///
/// L'utilisateur saisit sa carte bancaire directement dans l'application Flutter
/// sans redirection navigateur. Le backend fournit uniquement le `client_secret`
/// du PaymentIntent et la clé publique (`pk_test_...` / `pk_live_...`).
class StripePaymentService {
  const StripePaymentService();

  static const String _envPublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue:
        'pk_test_51Uc3mnL18pgVbexi516ZjjuIvsATz8hhKMDIqONgenbAzv2gsZyvT1RVpNifQ4uDO0aS9lenHSqxwfTeXbwAkDaw0040bvoKBW',
  );

  static String? _appliedPublishableKey;

  bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<PaymentSheetOutcome> payWithPaymentSheet({
    required String clientSecret,
    String? publishableKey,
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    if (!isPlatformSupported) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message:
            'Le paiement intégré Stripe PaymentSheet est disponible sur Android et iOS. '
            'Lancez l\'application sur un appareil ou émulateur mobile.',
      );
    }

    final resolvedKey = (publishableKey != null && publishableKey.trim().isNotEmpty)
        ? publishableKey.trim()
        : _envPublishableKey.trim();

    if (resolvedKey.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.server,
        message:
            'Clé publique Stripe (STRIPE_PUBLISHABLE_KEY) manquante. '
            'Ajoutez-la dans backend/.env ou via --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...',
      );
    }

    try {
      // Attention : ne pas lire le getter `Stripe.publishableKey` avant de l'avoir défini,
      // car `flutter_stripe` lève `StripeConfigException` tant qu'il est null.
      if (_appliedPublishableKey != resolvedKey) {
        Stripe.publishableKey = resolvedKey;
        await Stripe.instance.applySettings();
        _appliedPublishableKey = resolvedKey;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Studora',
          style: themeMode,
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                name: CollectionMode.automatic,
                email: CollectionMode.automatic,
              ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return PaymentSheetOutcome.submitted;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return PaymentSheetOutcome.canceled;
      }
      final rawMsg = e.error.localizedMessage ?? e.error.message ?? '';
      if (rawMsg.contains('elements/sessions') || rawMsg.contains('Failed to execute')) {
        throw const ApiException(
          kind: ApiErrorKind.network,
          message:
              'L\'émulateur ou l\'appareil n\'arrive pas à joindre les serveurs Stripe (api.stripe.com). '
              'Vérifiez la connexion Internet / DNS de l\'émulateur (ou redémarrez-le via Cold Boot).',
        );
      }
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: rawMsg.isNotEmpty
            ? rawMsg
            : 'Le paiement par carte bancaire a échoué.',
      );
    } on StripeConfigException catch (e) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: 'Configuration Stripe invalide : ${e.message}',
      );
    } on MissingPluginException {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message:
            'Plugin natif Stripe non chargé : arrêtez complètement l\'application (Stop) puis relancez un build complet (flutter run).',
      );
    } on PlatformException catch (e) {
      final msg = e.message ?? e.code;
      if (msg.contains('FlutterFragmentActivity') || msg.contains('Theme.AppCompat')) {
        throw const ApiException(
          kind: ApiErrorKind.unknown,
          message:
              'Configuration Android modifiée : arrêtez complètement l\'application (Stop) puis relancez un build complet (flutter run).',
        );
      }
      throw ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Erreur native Stripe : $msg',
      );
    } catch (e) {
      throw ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Impossible d\'ouvrir le module de paiement Stripe : $e',
      );
    }
  }
}
