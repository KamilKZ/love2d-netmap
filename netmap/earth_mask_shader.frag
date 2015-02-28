vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
	float norm = (Texel(texture, texture_coords).r); //it's b/w
	
	if (norm < 0.5f)
		return vec4(0.3f, 0.3f, 0.3f, 1.0f); // earth color
	else
		return vec4(0.4f, 0.4f, 0.4f, 1.0f); // water color
}