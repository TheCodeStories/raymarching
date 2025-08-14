float4 smoothMin(float4 a, float4 b, float smoothFactor)
{
    if (smoothFactor < 0.1)
    {
        return (a.a < b.a) ? a : b;
    }

    float da = a.a;
    float db = b.a;

    float wa = exp2(-da / smoothFactor);
    float wb = exp2(-db / smoothFactor);
    float wSum = wa + wb;

    float d = -smoothFactor * log2(wSum);
    float3 color = (a.rgb * wa + b.rgb * wb) / wSum;

    return float4(color, d);
}

float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

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
float sdUniformHollowCylinder(float3 p, float3 cylinder)
{
    float r1 = cylinder.x;
    float r2 = cylinder.y;
    float h  = cylinder.z;

    float radialDist = length(p.xz);

    float distOuter = radialDist - r2;
    float distInner = r1 - radialDist;
    float distY = abs(p.y) - h * 0.5;

    float2 d2 = float2(max(distOuter, distInner), distY);
    return min(max(d2.x, d2.y), 0.0) + length(max(d2, 0.0));
}

float sdHollowCylinder(float3 p, float3 cylinder)
{
    float r1 = cylinder.x; 
    float r2 = cylinder.y; 
    float h  = cylinder.z;

    float radialDist = length(p.xz);
    
    float t = saturate((r2 - radialDist) / (r2 - r1));
    float dynamicHeight = h + t * 0.5;

    float distOuter = radialDist - r2;
    float distInner = r1 - radialDist;
    float distY = abs(p.y) - dynamicHeight * 0.5;

    float2 d2 = float2(max(distOuter, distInner), distY);
    return min(max(d2.x, d2.y), 0.0) + length(max(d2, 0.0));
}

float sdOuterThickHollowCylinder(float3 p, float3 cylinder)
{
    float thicknessFactor = 10.0;
    float r1 = cylinder.x; 
    float r2 = cylinder.y; 
    float h  = cylinder.z;

    float radialDist = length(p.xz);

    float t = saturate((radialDist - r1) / (r2 - r1));
    float dynamicHeight = h + t * thicknessFactor;

    float distOuter = radialDist - r2;
    float distInner = r1 - radialDist;
    float distY = abs(p.y) - dynamicHeight * 0.5;

    float2 d2 = float2(max(distOuter, distInner), distY);
    return min(max(d2.x, d2.y), 0.0) + length(max(d2, 0.0));
}


float opU(float d1, float d2)
{
	return min(d1, d2);
}

float opS(float d1, float d2)
{
	return max(-d1, d2);
}

float opI(float d1, float d2)
{
	return max(d1, d2);
}

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

float2 rayBoxDistance(float3 bmin, float3 bmax, float3 ro, float3 rd)
{
    float3 inv = 1.0/rd;
    float3 t0  = (bmin - ro)*inv;
    float3 t1  = (bmax - ro)*inv;
    float3 tmin= min(t0,t1);
    float3 tmax= max(t0,t1);

    float entry = max(max(tmin.x,tmin.y), tmin.z);
    float exit  = min(min(tmax.x,tmax.y), tmax.z);

    bool inside = all(ro > bmin) && all(ro < bmax);
    if (inside) entry = 0;
    float distIn = max(0, exit-entry);
    return float2(max(0,entry), distIn);
}


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


float HG(float g, float ct)
{
    float d = 1 + g*g - 2*g*ct;
    return (1 - g*g)/(4*UNITY_PI*pow(d,1.5));
}
float doubleLobedHG(float ct, float g1, float g2, float w)
{
    return w*HG(g1,ct) + (1-w)*HG(g2,ct);
}


// float mod289(float x) {
//     return x - floor(x * (1.0 / 289.0)) * 289.0;
// }
// float3 mod289(float3 x) {
//     return x - floor(x * (1.0 / 289.0)) * 289.0;
// }
// float4 mod289(float4 x) {
//     return x - floor(x * (1.0 / 289.0)) * 289.0;
// }
// float4 permute(float4 x) {
//     return mod289((x * 34.0 + 1.0) * x);
// }
// float4 taylorInvSqrt(float4 r) {
//     return 1.79284291400159 - 0.85373472095314 * r;
// }

// float snoise(float3 v) {
//     const float2  C = float2(1.0 / 6.0, 1.0 / 3.0);
//     const float4  D = float4(0.0, 0.5, 1.0, 2.0);

//     // First corner
//     float3 i = floor(v + dot(v, C.yyy));
//     float3 x0 = v - i + dot(i, C.xxx);

//     // Other corners
//     float3 g = step(x0.yzx, x0.xyz);
//     float3 l = 1.0 - g;
//     float3 i1 = min(g.xyz, l.zxy);
//     float3 i2 = max(g.xyz, l.zxy);

//     // Offsets for second and third corners
//     float3 x1 = x0 - i1 + C.xxx;
//     float3 x2 = x0 - i2 + C.yyy;
//     float3 x3 = x0 - D.yyy;

//     // Permutations
//     i = mod289(i);
//     float4 p = permute(
//         permute(
//             permute(i.z + float4(0.0, i1.z, i2.z, 1.0))
//             + i.y + float4(0.0, i1.y, i2.y, 1.0))
//         + i.x + float4(0.0, i1.x, i2.x, 1.0));

//     // Gradients: 7x7 points over a square, mapped onto an octahedron.
//     float4 j = p - 49.0 * floor(p * (1.0 / 49.0));  // mod(p, 49)
//     float4 x_ = floor(j * (1.0 / 7.0));
//     float4 y_ = floor(j - 7.0 * x_);

//     float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
//     float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;

//     float4 h = 1.0 - abs(x) - abs(y);

//     float4 b0 = float4(x.xy, y.xy);
//     float4 b1 = float4(x.zw, y.zw);

//     float4 s0 = floor(b0) * 2.0 + 1.0;
//     float4 s1 = floor(b1) * 2.0 + 1.0;
//     float4 sh = -step(h, 0.0);

//     float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
//     float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

//     float3 g0 = float3(a0.xy, h.x);
//     float3 g1 = float3(a0.zw, h.y);
//     float3 g2 = float3(a1.xy, h.z);
//     float3 g3 = float3(a1.zw, h.w);

//     // Normalize gradients
//     float4 norm = taylorInvSqrt(float4(dot(g0,g0), dot(g1,g1), dot(g2,g2), dot(g3,g3)));
//     g0 *= norm.x;
//     g1 *= norm.y;
//     g2 *= norm.z;
//     g3 *= norm.w;

//     // Mix contributions from the four corners
//     float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
//     m = m * m;
//     return 42.0 * dot(m * m, float4(dot(g0,x0), dot(g1,x1), dot(g2,x2), dot(g3,x3)));
// }
