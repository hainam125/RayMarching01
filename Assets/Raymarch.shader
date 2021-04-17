Shader "PeerPlay/Raymarch" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader {
        Cull Off ZWrite Off ZTest Always

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0;

            #include "UnityCG.cginc"
            #include "DistanceFunctions.cginc"

            sampler2D _MainTex;
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum, _CamToWorld;

            uniform float _MaxDistance;
            uniform int _MaxIteration;
            uniform float _Accuracy;

            uniform fixed4 _MainColor;

            uniform float4 _Sphere;
            uniform float _SphereSmooth;
            uniform float _DegreeRotate;

            uniform float4 _LightDir;
            uniform float3 _LightCol;
            uniform float _LightIntensity;
            uniform float2 _ShadowDistance;
            uniform float _ShadowIntensity;
            uniform float _ShadowPenumbra;

            uniform float _AoStepSize;
            uniform float _AoIteration;
            uniform float _AoIntensity;

            uniform int _ReflectionCount;
            uniform float _ReflectionIntensity;
            uniform float _EnvReflectionIntensity;
            uniform samplerCUBE _ReflectionCube;


            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v) {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.ray = _CamFrustum[(int)index].xyz;
                //o.ray /= abs(o.ray.z);
                o.ray = mul(_CamToWorld, o.ray);
                return o;
            }

            float3 rotateY(float3 v, float degree) {
                float rad = 0.0174532925 * degree;
                float cosY = cos(rad);
                float sinY = sin(rad);
                return float3(cosY*v.x-sinY*v.z, v.y, sinY*v.x+cosY*v.z);
            }

            float distanceField(float3 p) {
                float ground = sdPlane(p, float4(0,1,0,0));
                float sphere = sdSphere(p - _Sphere.xyz, _Sphere.w);
                for(int i = 1; i < 8; i++) {
                    float sphereAdd = sdSphere(rotateY(p, _DegreeRotate * i) - _Sphere.xyz, _Sphere.w);
                    sphere = opUS(sphere, sphereAdd, _SphereSmooth);
                }
                return opU(sphere, ground);
            }

            float3 getNormal(float3 p) {
                const float2 offset = float2(0.001, 0.0);
                float3 n = float3(
                    distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
                    distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
                    distanceField(p + offset.yyx) - distanceField(p - offset.yyx)
                );
                return normalize(n);
            }

            //return 0 for shadow
            float hardShadow(float3 ro, float3 rd, float mint, float maxt) {
                for(float t = mint; t < maxt;){
                    float h = distanceField(ro + rd * t);
                    if (h < 0.001) {
                        return 0.0;
                    }
                    t += h;
                }
                return 1.0;
            }

            float softShadow(float3 ro, float3 rd, float mint, float maxt, float k) {
                float result = 1.0;
                for(float t = mint; t < maxt;){
                    float h = distanceField(ro + rd * t);
                    if (h < 0.001) {
                        return 0.0;
                    }
                    result = min(result, h * k / t);
                    t += h;
                }
                return result;
            }

            float ambientOcculusion(float3 p, float3 n) {
                float step =_AoStepSize;
                float ao = 0.0;
                float dist;

                for(int i = 1; i <= _AoIteration; i++) {
                    dist = step * i;
                    ao += max(0.0,(dist - distanceField(p + n * dist)) / dist);
                }
                return (1 - ao * _AoIntensity);
            }

            float3 shading(float3 p, float3 n) {
                float3 result;
                //diffuse color
                float3 color = _MainColor.rgb;

                //directional light
                float3 light = (_LightCol * dot(-_LightDir, n) * 0.5 + 0.5) * _LightIntensity;

                //shadows
                float shadow = softShadow(p, -_LightDir, _ShadowDistance.x, _ShadowDistance.y, _ShadowPenumbra) * 0.5 + 0.5;
                shadow = max(0, pow(shadow, _ShadowIntensity));

                //ambient occulusion
                float ao = ambientOcculusion(p, n);

                result = color * light * shadow * ao;
                return result;
            }

            bool raymarching(float3 ro, float3 rd, float depth, float maxDistance, int maxIteration, inout float3 p) {
                bool hit;
                float t = 0;//distance travelled along the ray direction
                for(int i = 0; i < maxIteration; i++) {
                    if (t > maxDistance || t >= depth){
                        //enviroment
                        hit = false;
                        break;
                    }
                    p = ro + rd * t;
                    //check for hit in distance field
                    float d = distanceField(p);
                    //we hit something
                    if (d < _Accuracy) {
                        hit = true;
                        break;
                    }
                    t += d;
                }
                return hit;
            }

            fixed4 frag (v2f i) : SV_Target {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture,i.uv).r);
                //depth *= length(i.ray);
                fixed3 col = tex2D(_MainTex, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result;
                float3 hitPosition;

                bool hit = raymarching(rayOrigin, rayDirection, depth, _MaxDistance, _MaxIteration, hitPosition);
                if (hit) {
                    //shading
                    float3 n = getNormal(hitPosition);
                    float3 s = shading(hitPosition, n);
                    result = fixed4(s, 1);
                }
                else {
                    result = fixed4(0,0,0,0);
                }

                return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
