export class Geohash {
  private static BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /**
   * Encode latitude/longitude to geohash
   * @param latitude - Latitude coordinate
   * @param longitude - Longitude coordinate
   * @param precision - Length of geohash (default: 5 = ~5km)
   * Precision levels:
   * 1 = ±2500 km
   * 2 = ±630 km
   * 3 = ±78 km
   * 4 = ±20 km
   * 5 = ±2.4 km (default for 5km radius)
   * 6 = ±0.61 km
   * 7 = ±0.076 km
   * 8 = ±0.019 km
   */
  static encode(latitude: number, longitude: number, precision: number = 5): string {
    const latRange = [-90.0, 90.0];
    const lonRange = [-180.0, 180.0];
    let geohash = '';
    let isEven = true;
    let bit = 0;
    let ch = 0;

    while (geohash.length < precision) {
      if (isEven) {
        const mid = (lonRange[0] + lonRange[1]) / 2;
        if (longitude > mid) {
          ch |= (1 << (4 - bit));
          lonRange[0] = mid;
        } else {
          lonRange[1] = mid;
        }
      } else {
        const mid = (latRange[0] + latRange[1]) / 2;
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
        geohash += this.BASE32[ch];
        bit = 0;
        ch = 0;
      }
    }

    return geohash;
  }

  /**
   * Get all neighboring geohashes (8 directions + center)
   * This ensures we catch users near boundaries
   */
  static neighbors(geohash: string): string[] {
    const top = this.neighbor(geohash, 'top');
    const bottom = this.neighbor(geohash, 'bottom');
    
    const neighbors = [
      geohash, // center
      top,
      bottom,
      this.neighbor(geohash, 'left'),
      this.neighbor(geohash, 'right'),
      top ? this.neighbor(top, 'left') : null,
      top ? this.neighbor(top, 'right') : null,
      bottom ? this.neighbor(bottom, 'left') : null,
      bottom ? this.neighbor(bottom, 'right') : null,
    ];
    
    return neighbors.filter(h => h !== null) as string[];
  }

  /**
   * Get neighboring geohash in specified direction
   */
  private static neighbor(geohash: string, direction: string): string | null {
    const lastChar = geohash[geohash.length - 1];
    const parent = geohash.slice(0, -1);
    const type = geohash.length % 2 === 0 ? 'even' : 'odd';

    // Neighbor finder lookup tables
    const neighbors: any = {
      right: { even: 'bc01fg45238967deuvhjyznpkmstqrwx', odd: 'p0r21436x8zb9dcf5h7kjnmqesgutwvy' },
      left: { even: '238967debc01fg45kmstqrwxuvhjyznp', odd: '14365h7k9dcfesgujnmqp0r2twvyx8zb' },
      top: { even: 'p0r21436x8zb9dcf5h7kjnmqesgutwvy', odd: 'bc01fg45238967deuvhjyznpkmstqrwx' },
      bottom: { even: '14365h7k9dcfesgujnmqp0r2twvyx8zb', odd: '238967debc01fg45kmstqrwxuvhjyznp' },
    };

    const borders: any = {
      right: { even: 'bcfguvyz', odd: 'prxz' },
      left: { even: '0145hjnp', odd: '028b' },
      top: { even: 'prxz', odd: 'bcfguvyz' },
      bottom: { even: '028b', odd: '0145hjnp' },
    };

    if (borders[direction][type].indexOf(lastChar) !== -1 && parent) {
      const parentNeighbor = this.neighbor(parent, direction);
      if (parentNeighbor === null) return null;
      return parentNeighbor + this.BASE32[neighbors[direction][type].indexOf(lastChar)];
    }

    return parent + this.BASE32[neighbors[direction][type].indexOf(lastChar)];
  }

  /**
   * Decode geohash to latitude/longitude bounds
   */
  static decode(geohash: string): { latitude: [number, number]; longitude: [number, number] } {
    const latRange = [-90.0, 90.0];
    const lonRange = [-180.0, 180.0];
    let isEven = true;

    for (let i = 0; i < geohash.length; i++) {
      const char = geohash[i];
      const idx = this.BASE32.indexOf(char);

      for (let j = 4; j >= 0; j--) {
        const bit = (idx >> j) & 1;

        if (isEven) {
          const mid = (lonRange[0] + lonRange[1]) / 2;
          if (bit === 1) {
            lonRange[0] = mid;
          } else {
            lonRange[1] = mid;
          }
        } else {
          const mid = (latRange[0] + latRange[1]) / 2;
          if (bit === 1) {
            latRange[0] = mid;
          } else {
            latRange[1] = mid;
          }
        }

        isEven = !isEven;
      }
    }

    return {
      latitude: [latRange[0], latRange[1]],
      longitude: [lonRange[0], lonRange[1]],
    };
  }

  /**
   * Get center point of geohash
   */
  static decodeCenter(geohash: string): { latitude: number; longitude: number } {
    const bounds = this.decode(geohash);
    return {
      latitude: (bounds.latitude[0] + bounds.latitude[1]) / 2,
      longitude: (bounds.longitude[0] + bounds.longitude[1]) / 2,
    };
  }
}