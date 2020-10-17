//Name of the shader
Shader "Hidden/GenCamNormals"
{
    Properties
    {

    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        Blend Off
        ZWrite On
        Cull Back
        ZTest LEqual //Default

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            //Define which functions to use as vertex/fragment shaders
            #pragma vertex vert
            #pragma fragment frag

            //Input for vertex shader
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            //Input for fragment shader
            struct Varyings
            {
                float4 vertex       : SV_POSITION;
                half3  normalWS     : TEXCOORD0;
            };

            //Vertex shader, nothing special
            Varyings vert(Attributes input)
            {
                //Initialise
                Varyings output = (Varyings)0;

                //Get pos
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;

                //Get normal
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = vertexNormalInput.normalWS;

                //Return
                return output;
            }

            //Fragment shader, the post-process effect is HERE
            half4 frag(Varyings input) : SV_Target
            {
                return float4((input.normalWS.xyz + 1.0f) * 0.5f, 1.f);
            }

            ENDHLSL
        }
    }
}