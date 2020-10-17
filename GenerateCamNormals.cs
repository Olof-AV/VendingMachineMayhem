using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class GenerateCamNormals : ScriptableRendererFeature
{
    ///Pass
    class CamNormalsPass : ScriptableRenderPass
    {
        //Constructor
        public CamNormalsPass(string _profilerTag)
        {
            this.profilerTag = _profilerTag;
        }

        //Internal stuff
        private Material material;
        private string profilerTag;
        private RenderTargetHandle tempRT;

        //Custom setup used by AddRenderPasses
        public void Setup()
        {
            //Setup material
            material = new Material(Shader.Find("Hidden/GenCamNormals"));

            //Setup custom RT
            tempRT = new RenderTargetHandle();
            tempRT.Init("_CustomCamNormals");
        }

        //Configure stuff like render target/clearing
        public override void Configure(CommandBuffer _cmd, RenderTextureDescriptor _cameraTextureDescriptor)
        {
            //Base
            base.Configure(_cmd, _cameraTextureDescriptor);

            //Get temp RT, setup pass to render to it/clear
            _cmd.GetTemporaryRT(tempRT.id, _cameraTextureDescriptor, FilterMode.Point);
            _cameraTextureDescriptor.depthBufferBits = 0;
            ConfigureTarget(tempRT.id);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        //Execute the render pass itself proper
        public override void Execute(ScriptableRenderContext _context, ref RenderingData _renderingData)
        {
            //Get command buffer to create draw commands
            CommandBuffer _cmd = CommandBufferPool.Get(profilerTag);

            //Magic happens in here
            {
                //Setup a draw call (opaque only, ALL masks, with custom normals material)
                List<ShaderTagId> _shaderTagIdList = new List<ShaderTagId>();
                _shaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
                _shaderTagIdList.Add(new ShaderTagId("UniversalForward"));
                _shaderTagIdList.Add(new ShaderTagId("LightweightForward"));
                DrawingSettings _drawSets = CreateDrawingSettings(_shaderTagIdList, ref _renderingData, _renderingData.cameraData.defaultOpaqueSortFlags);
                _drawSets.overrideMaterial = material;
                FilteringSettings _filterSets = new FilteringSettings(RenderQueueRange.opaque);
                RenderStateBlock _renderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);

                //Draw renderers -- the rendering layer masks provide the correct material
                _context.DrawRenderers(_renderingData.cullResults, ref _drawSets, ref _filterSets, ref _renderStateBlock);

                //Set params
                _cmd.SetGlobalTexture("_CustomCamNormals", tempRT.id);
            }

            //Execute the commands listed
            _context.ExecuteCommandBuffer(_cmd);

            //Erase the command buffer
            _cmd.Clear();
            CommandBufferPool.Release(_cmd);
        }

        //Cleanup after execution of the pass
        public override void FrameCleanup(CommandBuffer _cmd)
        {
            //Base
            base.FrameCleanup(_cmd);

            //Cleanup temp RT
            _cmd.ReleaseTemporaryRT(tempRT.id);
        }
    }
    private CamNormalsPass pass;

    //Create the pass
    public override void Create()
    {
        //Create pass with custom profiler tag (helps in frame debugger)
        name = "Generate Camera Normals";
        CamNormalsPass _pass = new CamNormalsPass(name);
        pass = _pass;

        //Renders before everything, makes sure the texture is available ASAP
        pass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
    }

    //Add this feature's pass to the renderer
    public override void AddRenderPasses(ScriptableRenderer _renderer, ref RenderingData _renderingData)
    {
        pass.Setup();
        _renderer.EnqueuePass(pass);
    }
}