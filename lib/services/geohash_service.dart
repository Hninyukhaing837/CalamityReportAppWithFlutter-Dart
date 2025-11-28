class GeohashService {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode latitude/longitude to geohash
  static String encode(double latitude, double longitude, {int precision = 5}) {
    List<double> latRange = [-90.0, 90.0];
    List<double> lonRange = [-180.0, 180.0];
    String geohash = '';
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (geohash.length < precision) {
      if (isEven) {
        final mid = (lonRange[0] + lonRange[1]) / 2;
        if (longitude > mid) {
          ch |= (1 << (4 - bit));
          lonRange[0] = mid;
        } else {
          lonRange[1] = mid;
        }
      } else {
        final mid = (latRange[0] + latRange[1]) / 2;
        if (latitude > mid) {
          ch |= (1 << (4 - bit));
          latRange[0] = mid;
        } else {
          latRange[1] = mid;
        }
      }

      isEven = !isEven;

      if (bit < 4) {
        bit++;
      } else {
        geohash += _base32[ch];
        bit = 0;
        ch = 0;
      }
    }

    return geohash;
  }
}