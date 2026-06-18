export interface Location {
  latitude: number;
  longitude: number;
}

export function calculateDistance(from: Location, to: Location): number {
  const R = 6371;
  const dLat = toRad(to.latitude - from.latitude);
  const dLon = toRad(to.longitude - from.longitude);
  const lat1 = toRad(from.latitude);
  const lat2 = toRad(to.latitude);

  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  return distance;
}

function toRad(degrees: number): number {
  return degrees * (Math.PI / 180);
}

export function estimateTransportationCost(
  distanceKm: number,
  options: {
    costPerKm?: number;
    baseFee?: number;
    roundTrip?: boolean;
  } = {}
): number {
  const {
    costPerKm = 0.5,
    baseFee = 5,
    roundTrip = true
  } = options;

  const tripMultiplier = roundTrip ? 2 : 1;
  const travelCost = distanceKm * tripMultiplier * costPerKm;
  const totalCost = baseFee + travelCost;

  return Math.round(totalCost * 100) / 100;
}

export function formatDistance(km: number): string {
  if (km < 1) {
    return `${Math.round(km * 1000)}m`;
  }
  return `${km.toFixed(1)}km`;
}
