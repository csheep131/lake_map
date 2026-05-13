#!/usr/bin/env python3
"""
Render MVT vector tiles from PMTiles to PNG raster tiles.
Uses mapbox-vector-tile + Pillow for rendering.
"""
import os, gzip, math, json
from pmtiles.reader import Reader, MmapSource
import mapbox_vector_tile
from PIL import Image, ImageDraw

PMTILES = '/home/schaf/projects/lake_map/wammsee.pmtiles'
OUT_DIR = '/home/schaf/projects/lake_map/server/public/tiles'
TILE_SIZE = 256

# Protomaps/OSM-style colors
COLORS = {
    'earth': (233, 229, 220),
    'landuse': (215, 230, 200),
    'water': (170, 211, 223),
    'natural': (200, 225, 190),
    'physical_line': (170, 211, 223),
    'roads': (255, 255, 255),
    'transit': (200, 200, 200),
    'buildings': (215, 210, 205),
    'boundaries': (180, 160, 200),
    'places': None,  # text labels, skip
    'pois': None,
    'landuse_labels': None,
    'natural_labels': None,
    'water_labels': None,
}

STROKE_COLORS = {
    'roads': (220, 220, 220),
    'boundaries': (180, 160, 200),
    'physical_line': (150, 190, 210),
    'transit': (180, 180, 180),
}

BACKGROUND = (242, 239, 233)  # Light beige

def mvt_to_pixel(geom_coords, extent=4096):
    """Convert MVT coordinates to pixel coordinates."""
    result = []
    for coord in geom_coords:
        if isinstance(coord, (list, tuple)) and len(coord) >= 2:
            if isinstance(coord[0], (int, float)):
                px = int(coord[0] * TILE_SIZE / extent)
                py = int(coord[1] * TILE_SIZE / extent)
                result.append((px, py))
            else:
                result.append(mvt_to_pixel(coord, extent))
    return result


def render_tile(tile_data, z):
    """Render a single MVT tile to a PIL Image."""
    img = Image.new('RGBA', (TILE_SIZE, TILE_SIZE), BACKGROUND + (255,))
    draw = ImageDraw.Draw(img)
    
    try:
        decoded = mapbox_vector_tile.decode(tile_data)
    except Exception as e:
        print(f"  Decode error: {e}")
        return img
    
    # Render layers in order
    layer_order = ['earth', 'landuse', 'natural', 'water', 'buildings', 
                   'roads', 'transit', 'boundaries', 'physical_line']
    
    for layer_name in layer_order:
        if layer_name not in decoded:
            continue
        layer = decoded[layer_name]
        extent = layer.get('extent', 4096)
        fill_color = COLORS.get(layer_name)
        stroke_color = STROKE_COLORS.get(layer_name)
        
        for feature in layer.get('features', []):
            geom = feature.get('geometry', {})
            geom_type = geom.get('type', '')
            coords = geom.get('coordinates', [])
            
            if geom_type == 'Polygon' and fill_color:
                for ring in coords:
                    pixels = mvt_to_pixel(ring, extent)
                    if len(pixels) >= 3:
                        draw.polygon(pixels, fill=fill_color + (255,), 
                                   outline=stroke_color + (255,) if stroke_color else None)
            
            elif geom_type == 'MultiPolygon' and fill_color:
                for polygon in coords:
                    for ring in polygon:
                        pixels = mvt_to_pixel(ring, extent)
                        if len(pixels) >= 3:
                            draw.polygon(pixels, fill=fill_color + (255,),
                                       outline=stroke_color + (255,) if stroke_color else None)
            
            elif geom_type == 'LineString' and stroke_color:
                pixels = mvt_to_pixel(coords, extent)
                if len(pixels) >= 2:
                    width = 2 if z >= 13 else 1
                    if layer_name == 'roads':
                        width = max(1, z - 10) if z >= 11 else 1
                    draw.line(pixels, fill=stroke_color + (255,), width=width)
            
            elif geom_type == 'MultiLineString' and stroke_color:
                for line in coords:
                    pixels = mvt_to_pixel(line, extent)
                    if len(pixels) >= 2:
                        width = 2 if z >= 13 else 1
                        if layer_name == 'roads':
                            width = max(1, z - 10) if z >= 11 else 1
                        draw.line(pixels, fill=stroke_color + (255,), width=width)
    
    return img


def main():
    with open(PMTILES, 'rb') as f:
        reader = Reader(MmapSource(f))
        count = 0
        
        for z in range(0, 15):
            def lat_lon_to_tile(lat, lon, zoom):
                lat_rad = math.radians(lat)
                n = 2.0 ** zoom
                x = int((lon + 180.0) / 360.0 * n)
                y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
                return x, y
            
            x_min, y_max = lat_lon_to_tile(49.325, 8.42, z)
            x_max, y_min = lat_lon_to_tile(49.36, 8.475, z)
            
            for x in range(max(0, x_min-1), min(2**z, x_max+2)):
                for y in range(max(0, y_min-1), min(2**z, y_max+2)):
                    tile_data = reader.get(z, x, y)
                    if tile_data:
                        # Decompress gzip
                        try:
                            decompressed = gzip.decompress(tile_data)
                        except:
                            decompressed = tile_data
                        
                        img = render_tile(decompressed, z)
                        
                        tile_dir = os.path.join(OUT_DIR, str(z), str(x))
                        os.makedirs(tile_dir, exist_ok=True)
                        img.save(os.path.join(tile_dir, f'{y}.png'), 'PNG')
                        count += 1
            
            if count > 0:
                print(f"  Zoom {z}: rendered")
        
        print(f"\nTotal: {count} PNG tiles rendered to {OUT_DIR}")


if __name__ == '__main__':
    main()
