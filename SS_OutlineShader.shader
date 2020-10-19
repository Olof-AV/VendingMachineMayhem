//Name of the post-process effect
Shader "Hidden/Outline"
{
    Properties
    {

    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        //Blend state
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

            ///Textures
            //Main render target
            TEXTURE2D(_CameraColorTexture);
            SAMPLER(sampler_CameraColorTexture);

            //We need depth for this post-process effect
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            //We need normals too, rendered from our custom render pass
            TEXTURE2D(_CustomCamNormals);
            SAMPLER(sampler_CustomCamNormals);

            //Outline custom colour, if not black then use this colour for outlines
            TEXTURE2D(_OutlineCustomCol);
            SAMPLER(sampler_OutlineCustomCol);

            //Outline custom depth
            TEXTURE2D(_OutlineCustomDep);
            SAMPLER(sampler_OutlineCustomDep);

            ///Parameters
            CBUFFER_START(UnityPerMaterial)
                float _Blend; //How much this post-process should apply on top of the original image
                float4 _CameraDepthTexture_TexelSize; //x and y hold the inverse size (so 1/width and 1/height)

                float4 _LineColour; //The colour to give our lines
                float _LineSize; //How big the lines should be

                float _KernelMult; //The multiplier to apply on the total
                float _KernelPower; //The power to apply on the total result
                float _KernelThreshold; //Above what value to show the lines

                float _NormalKernelMult; //The multiplier to apply on the total -- normals
                float _NormalKernelPower; //The power to apply on the total result -- normals
                float _NormalKernelThreshold; //Above what value to show the lines -- normals

                float _FogBrightness; //Affects when the fog kicks in
                float _FogInfluence; //Affects when the fog kicks in

                //float4 _OutlineCustomCol_ST; //Custom line colour render target <- Unneeded
                //float4 _OutlineCustomDepth_ST; //Custom line colour render target <- Unneeded
                float _OutlineCustomColSizeMult; //Size line multiplier for custom colours
            CBUFFER_END

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

            //Fragment shader, the post-process effect is HERE
            half4 frag(Varyings input) : SV_Target
            {
                //The sampled depth at this pixel is needed at many points, obtain it immediately
                const float sampledDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv);
                const float sampledCustomDepth = SAMPLE_DEPTH_TEXTURE(_OutlineCustomDep, sampler_OutlineCustomDep, input.uv);

                //Sample custom col, if there is any data (length of xyz > 0.0f) then replace default colour with custom colour/size
                //Custom object depth needs to be exactly equal to sampledDepth, otherwise you're dealing with some object in front
                const float4 sampledCustomLineColour = SAMPLE_TEXTURE2D(_OutlineCustomCol, sampler_OutlineCustomCol, input.uv);
                const float4 lineColour = (length(sampledCustomLineColour.xyz) > 0.0f && sampledCustomDepth == sampledDepth) ? sampledCustomLineColour : _LineColour;
                const float lineSize = (length(sampledCustomLineColour.xyz) > 0.0f && sampledCustomDepth == sampledDepth) ? _OutlineCustomColSizeMult * _LineSize : _LineSize;

                //Get final image colour
                float4 colour = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, input.uv);

                //Obtain fog factor to determine how much to fade lines
                //const float linearDepth = Linear01Depth(sampledDepth, _ZBufferParams);
                const float fogFactor = saturate((_FogBrightness * _FogBrightness) * (1.f - pow(abs(1.f - sampledDepth), 1.f / (_FogInfluence * _FogInfluence))));

                //Can use swizzling to make this less painful
                const float3 offset = float3(_CameraDepthTexture_TexelSize.xy, 0.f) * lineSize;

                ///Outlines by depth
                {
                    //Sample nearby pixels and middle
                    float total = sampledDepth * 4.f;
                    total -= SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv + offset.xz); //Right
                    total -= SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv + offset.zy); //Top
                    total -= SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv - offset.xz); //Left
                    total -= SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv - offset.zy); //Bottom

                    //If you accept both above and under 0.f, you get double the lines
                    if (total > 0.f)
                    {
                        //Apply modifiers on the resulting difference
                        total *= _KernelMult;
                        total = pow(abs(total), _KernelPower);

                        //Blend accordingly with original image and return
                        colour = lerp(colour, lineColour, fogFactor * _Blend * smoothstep(0.f, _KernelThreshold, total));

                        //return (total > _Threshold) ? lerp(colour, _LineColour, _Blend) : colour;
                    }
                }

                ///Outlines by normal
                {
                    const float3 worldNormal = SAMPLE_TEXTURE2D(_CustomCamNormals, sampler_CustomCamNormals, input.uv).xyz * 2.0f - 1.0f;
                    float total = 4.0f;
                    total -= dot(worldNormal, SAMPLE_TEXTURE2D(_CustomCamNormals, sampler_CustomCamNormals, input.uv + offset.xz).xyz * 2.0f - 1.0f); //Right
                    total -= dot(worldNormal, SAMPLE_TEXTURE2D(_CustomCamNormals, sampler_CustomCamNormals, input.uv + offset.zy).xyz * 2.0f - 1.0f); //Top
                    total -= dot(worldNormal, SAMPLE_TEXTURE2D(_CustomCamNormals, sampler_CustomCamNormals, input.uv - offset.xz).xyz * 2.0f - 1.0f); //Left
                    total -= dot(worldNormal, SAMPLE_TEXTURE2D(_CustomCamNormals, sampler_CustomCamNormals, input.uv - offset.zy).xyz * 2.0f - 1.0f); //Bottom

                    //Can't apply a power on value > 0.0f
                    if (total > 0.0f)
                    {
                        //Apply modifiers
                        total *= _NormalKernelMult;
                        total = pow(abs(total), _NormalKernelPower);

                        //Blend with original image
                        colour = lerp(colour, lineColour, fogFactor * _Blend * smoothstep(0.0f, _NormalKernelThreshold, total));
                    }
                }

                //Return final result
                return colour;
            }

            ENDHLSL
        }
    }
}