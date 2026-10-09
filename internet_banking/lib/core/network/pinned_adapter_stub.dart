import 'package:dio/dio.dart';

import 'certificate_pinning.dart';

/// Web: the browser owns TLS, so the app cannot pin; requests use the default transport.
HttpClientAdapter? pinnedHttpClientAdapter(CertificatePinPolicy policy) => null;
