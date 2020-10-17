//Name of the post-process effect
Shader "Hidden/CA_Shader"
{
    Properties
    {

    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        //Blend state
        /*Cull Back
        ZWrite Off
        ColorMask RGB
        Blend SrcAlpha OneMinusSrcAlpha*/
        ColorMask RGB
        ZWrite Off
        Cull Off
        ZTest Always

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            //Extra features
            //#pragma multi_compile_fog

            //Define which functions to use as vertex/fragment shaders
            #pragma vertex vert
            #pragma fragment frag

            //Main render target
            TEXTURE2D(_CameraColorTexture);
            SAMPLER(sampler_CameraColorTexture);

            //We need depth for this post-process effect
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float _Blend; //How much this post-process should apply on top of the original image
            float _Intensity;

            float _Bend;
            float _BendInfluence;

            //Input for vertex shader
            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
            };

            //Input for fragment shader
            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 vertex       : SV_POSITION;
            };

            //Vertex shader, nothing special
            Varyings vert(Attributes input)
            {
                //Initialise
                Varyings output = (Varyings)0;

                //Get pos and uv, return
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = input.uv;

                return output;
            }

            //From a set of original UV coordinates, return transformed bent coordinates
            float2 GetBentCoords(float2 uv)
            {
                //Move to -1,1 range
                uv -= 0.5f;
                uv *= 2.f;

                //Bend happens according to the other axis
                uv.x *= 1.f - pow(abs(abs(uv.y) / _Bend), _BendInfluence) * _Blend;
                uv.y *= 1.f - pow(abs(abs(uv.x) / _Bend), _BendInfluence) * _Blend;

                //Back to 0,1 range
                uv *= 0.5f;
                return uv + 0.5f;
            }

            //Fragment shader, the post-process effect is HERE
            half4 frag(Varyings input) : SV_Target
            {
                //Get original image colour
                float4 colour = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, GetBentCoords(input.uv));

                //Compare pixel to center
                //Don't bend the direction, otherwise you get quite unexpected results
                float2 dir = (float2(0.5f, 0.5f) - input.uv);

                //Distortion intensity comes into play here
                //The offset sampling point (seen in green and red channel) is distorted too
                float blue = colour.b;
                float green = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, GetBentCoords(input.uv + dir * 0.01f * _Intensity * _Blend)).g;
                float red = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, GetBentCoords(input.uv + dir * 0.02f * _Intensity * _Blend)).r;

                //Return result
                return float4(red, green, blue, 1.f);
            }

            ENDHLSL
        }
    }
}