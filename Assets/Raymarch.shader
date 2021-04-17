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

            sampler2D _MainTex;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _MaxDistance;

            uniform float4 _LightDir;
            uniform float4 _Sphere1;

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
                o.ray /= abs(o.ray.z);
                o.ray = mul(_CamToWorld, o.ray);
                return o;
            }

            float sdSphere(float3 p, float r) {
                return length(p) - r;
            }

            float distanceField(float3 p) {
                float sphere1 = sdSphere(p - _Sphere1.xyz, _Sphere1.w);
                return sphere1;
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

            fixed4 raymarching(float3 ro, float3 rd) {
                fixed4 result = fixed4(1,1,1,1);
                const int max_iteration = 128;
                float t = 0;//distance travelled along the ray direction
                for(int i = 0; i < max_iteration; i++) {
                    if (t > _MaxDistance){
                        //enviroment
                        result = fixed4(rd,1);
                        break;
                    }
                    float3 p = ro + rd * t;
                    //check for hit in distance field
                    float d = distanceField(p);
                    //we hit something
                    if (d < 0.01) {
                        //shading
                        float3 n = getNormal(p);
                        float light = dot(-_LightDir, n);
                        result = fixed4(1,1,1,1) * light;
                        break;
                    }
                    t += d;
                }
                return result;
            }

            fixed4 frag (v2f i) : SV_Target {
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection);
                return result;
            }
            ENDCG
        }
    }
}
