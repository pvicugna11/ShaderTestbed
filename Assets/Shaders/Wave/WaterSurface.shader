Shader "Unlit/WaterSurface"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _HeightMap ("Height Map", 2D) = "gray" {}
        _RelativeRefractionIndex ("Relative Refraction Index", Range(0, 1)) = .75
        _Distance ("Distance", Range(0, 100)) = 10
        _MinTessDistance ("Min Tessellation Distance", Range(0, 50)) = 10
        _MaxTessDistance ("Max Tessellation Distance", Range(0, 50)) = 25
        _Tess ("Tessellation", Range(0, 50)) = 10
        _Displacement ("Displacement", Range(0, 1)) = .3
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma require tessellation
            #pragma vertex TessellationVertexProgram
            #pragma fragment frag
            #pragma hull hull
            #pragma domain domain

            #include "UnityCG.cginc"

            half4 _BaseColor;

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                half2 samplingViewportPos : TEXCOORD3;
            };

            struct ControlPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
            };

            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            sampler2D _CameraOpaqueTexture;
            sampler2D _HeightMap;
            float4 _HeightMap_TexelSize;
            float _RelativeRefractionIndex;
            float _Distance;
            float _MinTessDistance;
            float _MaxTessDistance;
            float _Tess;
            float _Displacement;

            ControlPoint TessellationVertexProgram(Attributes v)
            {
                ControlPoint p;
                p.vertex = v.vertex;
                p.uv = v.uv;
                return p;
            }

            [UNITY_domain("tri")]
            [UNITY_outputcontrolpoints(3)]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_partitioning("fractional_odd")]
            [UNITY_patchconstantfunc("patchConstantFunction")]
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float3 worldPosition = mul(unity_ObjectToWorld, vertex).xyz;
                float dist = distance(worldPosition, _WorldSpaceCameraPos);
                float f = clamp(1 - (dist - minDist) / (maxDist - minDist), .01, 1) * tess;
                return (f);
            }

            TessellationFactors patchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                float minDist = _MinTessDistance;
                float maxDist = _MaxTessDistance;

                TessellationFactors f;

                float edge0 = CalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess);

                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            Varyings vert(Attributes v)
            {
                // ハイトマップからノーマルマップを生成
                // テクセルサイズを取得
                float2 stride = float2(_HeightMap_TexelSize.xy);
                // 隣接するテクセルの情報を取得
                float xP = tex2Dlod(_HeightMap, float4(v.uv.x + stride.x, v.uv.y, 0, 0)).r;
                float xM = tex2Dlod(_HeightMap, float4(v.uv.x - stride.x, v.uv.y, 0, 0)).r;
                float yP = tex2Dlod(_HeightMap, float4(v.uv.x, v.uv.y + stride.y, 0, 0)).r;
                float yM = tex2Dlod(_HeightMap, float4(v.uv.x, v.uv.y - stride.y, 0, 0)).r;
                // 勾配を計算
                float3 du = float3(1, (xP - xM), 0);
                float3 dv = float3(0, (yP - yM), 1);
                // ノーマルを計算
                float3 normal = normalize(cross(du, dv));
                float3 worldNormal = UnityObjectToWorldNormal(normal);

                // 頂点移動
                float d = tex2Dlod(_HeightMap, float4(v.uv, 0, 0)).r * _Displacement;
                v.vertex.xyz += normal * d;

                // ワールド座標系の位置
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                // 屈折のサンプリング位置を決定
                // ワールド座標系の視野ベクトル
                half3 worldViewDir = normalize(worldPos - _WorldSpaceCameraPos);
                // 屈折方向を求める
                half3 refractDir = refract(worldViewDir, worldNormal, _RelativeRefractionIndex);
                // 屈折方向の先にある位置をサンプリング位置とする
                half3 samplingPos = worldPos + refractDir * _Distance;
                // サンプリング位置をプロジェクション変換
                half4 samplingScreenPos = mul(UNITY_MATRIX_VP, half4(samplingPos, 1.0));
                // ビューポート座標系に変換
                half2 samplingViewportPos = (samplingScreenPos.xy / samplingScreenPos.w) * 0.5 + 0.5;
                samplingViewportPos.y = 1 - samplingViewportPos.y;

                // 出力
                Varyings o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = worldPos;
                o.normal = normal;
                o.worldNormal = worldNormal;
                o.samplingViewportPos = samplingViewportPos;
                return o;
            }

            [UNITY_domain("tri")]
            Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Attributes v;

#define DomainCalc(fieldName) v.fieldName = \
                    patch[0].fieldName * barycentricCoordinates.x + \
                    patch[1].fieldName * barycentricCoordinates.y + \
                    patch[2].fieldName * barycentricCoordinates.z;

                    DomainCalc(vertex)
                    DomainCalc(uv)

                return vert(v);
            }

            fixed4 frag (Varyings i) : SV_Target
            {
                // ワールド座標系の視野ベクトル
                half3 worldViewDir = normalize(i.worldPos - _WorldSpaceCameraPos);

                // 屈折
                half4 refractColor = tex2D(_CameraOpaqueTexture, i.samplingViewportPos);

                // ライトによる色
                float3 lightDir = normalize(_WorldSpaceLightPos0 - i.worldPos);
                float diff = max(0.9, dot(i.normal, lightDir)); // 明るくなるように
                half4 baseColor = half4(_BaseColor.rgb * refractColor * diff, _BaseColor.a);

                // 反射
                half3 reflDir = reflect(worldViewDir, i.worldNormal);
                half4 reflColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0);

                // フレネル
                half fresenl = dot(worldViewDir, i.worldNormal);
                half fresenl0 = .2;
                fresenl = fresenl0 + (1 - fresenl0) * pow((1 - fresenl), 5);

                half4 col = lerp(baseColor, reflColor, fresenl);
                return fixed4(col);
            }
            ENDHLSL
        }
    }
}
