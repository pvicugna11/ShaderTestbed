Shader "Unlit/Wave"
{
    Properties
    {
        _C ("Phase Velocity^2", Range(0, .5)) = .1      // 伝播速度の2乗
        _Attenuation ("Attenuation", Range(0, 1)) = .99 // 減衰
        _Stride ("Stride", Float) = 1                   // 微小区間
    }
    SubShader
    {
        Pass
        {
            Name "Update"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag

            #include "UnityCustomRenderTexture.cginc"

            half _C;
            half _Attenuation;
            float _Stride;

            float4 frag (v2f_customrendertexture i) : SV_Target
            {
                // CustomRenderTextureのuv座標
                float2 uv = i.globalTexcoord;

                // 1pxあたりの単位
                float du = 1 / _CustomRenderTextureWidth;
                float dv = 1 / _CustomRenderTextureHeight;
                float2 stride = float2(du, dv) * _Stride;

                // 現在のテクスチャ
                float2 c = tex2D(_SelfTexture2D, uv);

                // 波動方程式
                // h(t + 1) = 2h(t) - h(t - 1) + c * (h(x + 1) + h(x - 1) + h(y + 1) + h(y - 1) - 4h(t))
                half value = 
                    (c.r * 2 - c.g +
                    (tex2D(_SelfTexture2D, float2(uv.x + stride.x, uv.y)).r +
                     tex2D(_SelfTexture2D, float2(uv.x - stride.x, uv.y)).r +
                     tex2D(_SelfTexture2D, float2(uv.x, uv.y + stride.y)).r +
                     tex2D(_SelfTexture2D, float2(uv.x, uv.y - stride.y)).r -
                     c.r * 4) * _C);
                // 減衰
                value *= _Attenuation;

                // R：現在の高さ G：1フレーム前の高さ
                return float4(value, c.r, 0, 0);
            }
            ENDCG
        }

        Pass
        {
            Name "LeftClick"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment fragLeftClick

            #include "UnityCustomRenderTexture.cginc"

            float4 fragLeftClick (v2f_customrendertexture i) : SV_Target
            {
                return float4(-1, 0, 0, 0);
            }
            ENDCG
        }

        Pass
        {
            Name "RightClick"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment fragRightClick

            #include "UnityCustomRenderTexture.cginc"

            float4 fragRightClick (v2f_customrendertexture i) : SV_Target
            {
                return float4(1, 0, 0, 0);
            }
            ENDCG
        }
    }
}
