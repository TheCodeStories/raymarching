// Sphere
// s: radius
float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

// Box
// b: size of box in x/y/z
float sdBox(float3 p, float3 b)
{
	float3 d = abs(p) - b;
	return min(max(d.x, max(d.y, d.z)), 0.0) +
		length(max(d, 0.0));
}

float sdTorus( float3 p, float2 t )
{
  float2 q = float2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sdTorusFlattened(float3 p, float3 t)
{
    // squash the Y-axis in the distance computation
    float2 q = float2(length(p.xz) - t.x, p.y * t.z);
    return length(q) - t.y;
}

float sdHexPrism( float3 p, float2 h )
{
  const float3 k = float3(-0.8660254, 0.5, 0.57735);
  p = abs(p);
  p.xy -= 2.0*min(dot(k.xy, p.xy), 0.0)*k.xy;
  float2 d = float2(
       length(p.xy-float2(clamp(p.x,-k.z*h.x,k.z*h.x), h.x))*sign(p.y-h.x),
       p.z-h.y );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdOctahedron( float3 p, float s )
{
  p = abs(p);
  float m = p.x+p.y+p.z-s;
  float3 q;
       if( 3.0*p.x < m ) q = p.xyz;
  else if( 3.0*p.y < m ) q = p.yzx;
  else if( 3.0*p.z < m ) q = p.zxy;
  else return m*0.57735027;
    
  float k = clamp(0.5*(q.z-q.y+s),0.0,s); 
  return length(float3(q.x,q.y-s+k,q.z-k)); 
}

// BOOLEAN OPERATORS //

// Union
float opU(float d1, float d2)
{
	return min(d1, d2);
}

// Subtraction
float opS(float d1, float d2)
{
	return max(-d1, d2);
}

// Intersection
float opI(float d1, float d2)
{
	return max(d1, d2);
}

// Mod Position Axis
float pMod1 (inout float p, float size)
{
	float halfsize = size * 0.5;
	float c = floor((p+halfsize)/size);
	p = fmod(p+halfsize,size)-halfsize;
	p = fmod(-p+halfsize,size)-halfsize;
	return c;
}

float4 morphSDF(float4 a, float4 b, float t)
{
	float d = lerp(a.w, b.w, t);
	float3 color = lerp(a.rgb, b.rgb, t);
	return float4(color, d);
}

float3 rotateX(float3 p, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float3(
        p.x,
        c * p.y - s * p.z,
        s * p.y + c * p.z
    );
}


// quaternion squaring & cubing
float4 qSquare(in float4 q) {
    return float4(q.x*q.x - dot(q.yzw,q.yzw),
                  2.0*q.x*q.y, 2.0*q.x*q.z, 2.0*q.x*q.w);
}
float4 qCube(in float4 q) {
    float4 q2 = q*q;
    return float4(
      q.x*(q2.x - 3.0*(q2.y+q2.z+q2.w)),
      q.y*(3.0*(q2.x) - (q2.y+q2.z+q2.w)),
      q.z*(3.0*(q2.x) - (q2.y+q2.z+q2.w)),
      q.w*(3.0*(q2.x) - (q2.y+q2.z+q2.w))
    );
}
float qLength2(in float4 q) { return dot(q,q); }

// your uniform for the Julia constant:
uniform float4 _JuliaC;

// returns (distance, iterationCount)




            // float4 sdf(float3 position)
            // {
            //     float4 sphere      = float4(_SphereColor.rgb, sDSphere(position - _Sphere.xyz, _Sphere.w));
            //     float4 box         = float4(_BoxColor.rgb,    sDBox(position - _Box.xyz,    _Box.w));
            //     float angle = -3.14159 * 0.5; // -90 degrees in radians
            //     float3 rotatedPos = rotateX(position - float3(0, 0, 0), angle); // center at (0,0,0)

            //     float4 torus = float4(1.0, 1.0, 0.0, sdTorus(rotatedPos, float2(2.0, 1.0)));
            //     // float4 torus       = float4(1.0, 1.0, 0.0,     sdTorus(position - float3(0, 0, 0), float2(1.0, 2.0)));
            //     float4 hex         = float4(1.0, 0.0, 1.0,     sdHexPrism(position - float3(0, 0, 0), float2(1.0, 2.0)));
            //     float4 octahedron  = float4(0.0, 1.0, 1.0,     sdOctahedron(position - float3(0, 0, 0), 2.0));

            //     float t = _BlendFactor;
                
            //     if (t < 1.0)
            //     {
            //         return morphSDF(sphere, box, t);
            //     }
            //     else if (t < 2.0)
            //     {
            //         return morphSDF(box, torus, t - 1.0);
            //     }
            //     else if (t < 3.0)
            //     {
            //         return morphSDF(torus, hex, t - 2.0);
            //     }
            //     else if (t < 4.0)
            //     {
            //         return morphSDF(hex, octahedron, t - 3.0);
            //     }
            //     else
            //     {
            //         // Clamp at last shape
            //         return octahedron;
            //     }
            // }