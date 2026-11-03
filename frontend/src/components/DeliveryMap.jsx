import { useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';

const pin = (color, glyph) => L.divIcon({
  className: '',
  html: `<div class="pin" style="background:${color}">${glyph}</div>`,
  iconSize: [32, 32], iconAnchor: [16, 32], popupAnchor: [0, -30],
});
const ICONS = { pickup: pin('#0f766e', 'A'), dropoff: pin('#ea580c', 'B'), courier: pin('#1e293b', '➤') };

function Fit({ points }) {
  const map = useMap();
  const key = points.map((p) => `${p.lat.toFixed(4)},${p.lng.toFixed(4)}`).join('|');
  useEffect(() => {
    if (points.length === 1) map.setView([points[0].lat, points[0].lng], 14);
    else if (points.length > 1) map.fitBounds(points.map((p) => [p.lat, p.lng]), { padding: [40, 40] });
  }, [key]); // eslint-disable-line react-hooks/exhaustive-deps
  return null;
}

export default function DeliveryMap({ pickup, dropoff, courier, others = [], height = 360 }) {
  const pts = [pickup, dropoff, courier, ...others.map((o) => o.location)].filter((p) => p && Number.isFinite(p.lat));
  return (
    <MapContainer center={[48.8566, 2.3522]} zoom={12} style={{ height, borderRadius: 12 }} scrollWheelZoom>
      <TileLayer attribution='&copy; OpenStreetMap' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
      {pickup?.lat && <Marker position={[pickup.lat, pickup.lng]} icon={ICONS.pickup}><Popup>Retrait : {pickup.address}</Popup></Marker>}
      {dropoff?.lat && <Marker position={[dropoff.lat, dropoff.lng]} icon={ICONS.dropoff}><Popup>Livraison : {dropoff.address}</Popup></Marker>}
      {pickup?.lat && dropoff?.lat && <Polyline positions={[[pickup.lat, pickup.lng], [dropoff.lat, dropoff.lng]]} pathOptions={{ color: '#0f766e', dashArray: '6 8' }} />}
      {courier?.lat && <Marker position={[courier.lat, courier.lng]} icon={ICONS.courier}><Popup>Coursier</Popup></Marker>}
      {others.filter((o) => o.location).map((o) => (
        <Marker key={o.id} position={[o.location.lat, o.location.lng]} icon={ICONS.courier}><Popup>{o.label}</Popup></Marker>
      ))}
      <Fit points={pts} />
    </MapContainer>
  );
}
