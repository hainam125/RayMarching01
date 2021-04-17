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

            uniform fixed4 _MainColor;
            uniform float4 _Sphere1, _Box1;
            uniform float3 _ModInterval;


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

            float distanceField(float3 p) {
                float modX = pMod1(p.x, _ModInterval.x);
                float modY = pMod1(p.y, _ModInterval.y);
                float modZ = pMod1(p.z, _ModInterval.z);
                float sphere1 = sdSphere(p - _Sphere1.xyz, _Sphere1.w);
                float box1 = sdBox(p - _Box1.xyz, _Box1.www);
                return opS(sphere1, box1);
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
                        float light = dot(-_LightDir, n);
                        result = fixed4(_MainColor.rgb * light,1);
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
