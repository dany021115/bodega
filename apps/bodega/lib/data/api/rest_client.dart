import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'rest_client.g.dart';

@RestApi(baseUrl: 'https://raw.githubusercontent.com/')
abstract class RestClient {
  factory RestClient(Dio dio) = _RestClient;

  /// Served as text/plain, so it is decoded apart (design §4).
  @GET('gauthierpiarrette/highball-db/f0bf6a2/db/anticheat.json')
  @DioResponseType(ResponseType.plain)
  Future<String> antiCheat();
}
