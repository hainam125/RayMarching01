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

            fixed4 raymarching(float3 ro, float3 rd) {
                fixed4 result = fixed4(1,1,1,1);
                const int max_iteration = 64;
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
                        result = fixed4(1,1,1,1);
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
