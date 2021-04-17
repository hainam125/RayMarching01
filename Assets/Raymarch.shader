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

            uniform float4 _LightDir;
            uniform float3 _LightCol;
            uniform float _LightIntensity;
            uniform float2 _ShadowDistance;
            uniform float _ShadowIntensity;
            uniform float _ShadowPenumbra;

            uniform fixed4 _MainColor;
            uniform float4 _Sphere1, _Sphere2, _Box1;
            uniform float _Box1Round;
            uniform float _BoxSphereSmooth;
            uniform float _SphereIntersectSmooth;


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

            float BoxSphere(float3 p) {
                float sphere1 = sdSphere(p - _Sphere1.xyz, _Sphere1.w);
                float box1 = sdRoundBox(p - _Box1.xyz, _Box1.www, _Box1Round);
                float combine1 = opSS(sphere1, box1, _BoxSphereSmooth);

                float sphere2 = sdSphere(p - _Sphere2.xyz, _Sphere2.w);
                float combine2 = opIS(sphere2, combine1, _SphereIntersectSmooth);

                return combine2;
            }

            float distanceField(float3 p) {
                float ground = sdPlane(p, float4(0,1,0,0));
                float boxSphere1 = BoxSphere(p);

                return opU(ground, boxSphere1);
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

            float3 shading(float3 p, float3 n) {
                //directional light
                float result = (_LightCol * dot(-_LightDir, n) * 0.5 + 0.5) * _LightIntensity;
                //shadows
                float shadow = softShadow(p, -_LightDir, _ShadowDistance.x, _ShadowDistance.y, _ShadowPenumbra) * 0.5 + 0.5;
                shadow = max(0, pow(shadow, _ShadowIntensity));
                result *= shadow;
                return result;
            }

            fixed4 raymarching(float3 ro, float3 rd, float depth) {
                fixed4 result = fixed4(1,1,1,1);
                const int max_iteration = 128;
                float t = 0;//distance travelled along the ray direction
                for(int i = 0; i < max_iteration; i++) {
                    if (t > _MaxDistance || t >= depth){
                        //enviroment
                        result = fixed4(rd,0);
                        break;
                    }
                    float3 p = ro + rd * t;
                    //check for hit in distance field
                    float d = distanceField(p);
                    //we hit something
                    if (d < 0.01) {
                        //shading
                        float3 n = getNormal(p);
                        float3 s = shading(p, n);
                        result = fixed4(_MainColor.rgb * s,1);
                        break;
                    }
                    t += d;
                }
                return result;
            }

            fixed4 frag (v2f i) : SV_Target {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture,i.uv).r);
                //depth *= length(i.ray);
                fixed3 col = tex2D(_MainTex, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection, depth);
                return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
