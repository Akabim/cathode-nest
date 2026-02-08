shader_type canvas_item;

// Wajib di Godot 4 untuk baca layar di belakangnya
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- PENGATURAN (Diatur di Inspector) ---

group_uniforms Screen_Shape;
// Seberapa cembung layarnya (Barrel Distortion)
uniform float curvature : hint_range(0.0, 10.0) = 4.0;
// Warna hitam di pinggiran layar cembung
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

group_uniforms CRT_Effects;
// Efek warna bleber (Merah & Biru kepisah di pinggir)
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.005;
// Seberapa gelap pojok-pojok layar
uniform float vignette_darkness : hint_range(0.0, 1.0) = 0.5;

group_uniforms Scanlines_and_Noise;
// Jumlah garis TV
uniform float scanline_count : hint_range(0.0, 1080.0) = 300.0;
// Kegelapan garis
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.4;
// Kecepatan garis bergerak ke atas (Animasi!)
uniform float scanline_roll_speed : hint_range(-2.0, 2.0) = 0.5;
// Efek semut/pasir (Static Noise)
uniform float noise_strength : hint_range(0.0, 0.5) = 0.05;
// Kecepatan kedip layar (Flicker)
uniform float flicker_speed : hint_range(0.0, 10.0) = 5.0;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.02;


// Fungsi untuk membuat efek cembung
vec2 curve(vec2 uv) {
	if (curvature <= 0.0) return uv;
	uv = (uv - 0.5) * 2.0; // Pusatkan koordinat
	vec2 offset = vec2(uv.y, uv.x) / curvature;
	uv = uv + uv * offset * offset;
	uv = uv * 0.5 + 0.5; // Kembalikan normal
	return uv;
}

// Fungsi pembuat noise acak
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- 1. LENGKUNGKAN LAYAR (Curvature) ---
	vec2 warped_uv = curve(uv);

	// Cek area di luar lengkungan, warnai hitam
	if (warped_uv.x < 0.0 || warped_uv.x > 1.0 || warped_uv.y < 0.0 || warped_uv.y > 1.0) {
		COLOR = vignette_color;
	} else {
		// --- 2. CHROMATIC ABERRATION (Warna Bleber) ---
		// Baca tekstur 3 kali dengan posisi sedikit bergeser untuk R dan B
		float r = texture(SCREEN_TEXTURE, warped_uv + vec2(chromatic_aberration, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, warped_uv).g;
		float b = texture(SCREEN_TEXTURE, warped_uv - vec2(chromatic_aberration, 0.0)).b;
		vec3 final_color = vec3(r, g, b);

		// --- 3. SCANLINES BERGERAK (Animasi!) ---
		// Menggunakan TIME untuk menggerakkan posisi garis
		float scanline = sin((warped_uv.y - TIME * scanline_roll_speed) * scanline_count * PI * 2.0);
		scanline = (scanline + 1.0) * 0.5; // Normalisasi 0.0 - 1.0
		// Terapkan kegelapan garis
		final_color -= scanline * scanline_opacity;

		// --- 4. NOISE (Semut) ---
		// Noise acak yang berubah tiap waktu
		float grain = random(warped_uv + vec2(TIME * 10.0));
		final_color += (grain - 0.5) * noise_strength;

		// --- 5. FLICKER (Kedip-kedip halus) ---
		float flicker = 1.0 + sin(TIME * flicker_speed) * flicker_intensity;
		final_color *= flicker;

		// --- 6. VIGNETTE (Pojok Gelap) ---
		float dist_from_center = distance(warped_uv, vec2(0.5));
		final_color *= (1.0 - dist_from_center * vignette_darkness);

		// Output akhir
		COLOR = vec4(final_color, 1.0);
	}
}