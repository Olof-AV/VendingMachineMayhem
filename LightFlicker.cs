using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public sealed class LightFlicker : MonoBehaviour
{
    [Header("Main")]
    [SerializeField] private Light attachedLight = null;
    private float initialLightIntensity = 0.0f;
    [SerializeField] private Renderer attachedMesh = null;
    private float initialEmissiveIntensity = 0.0f;
    private MaterialPropertyBlock mpb = null;

    [Header("Light Flickering Parameters")]
    [SerializeField] private float threshold = 0.1f;
    [SerializeField] private int octaves = 4;
    [SerializeField] private float lacunarity = 12.0f;
    [SerializeField] private float gain = 0.5f;
    [SerializeField] private float initialFrequency = 10.0f;
    [SerializeField] private float initialAmplitude = 1.0f;
    [SerializeField] private bool invertThresholdCondition = false;

    //Save light initial intensity
    void Awake()
    {
        if(attachedLight)
        {
            initialLightIntensity = attachedLight.intensity;
        }
        if(attachedMesh)
        {
            initialEmissiveIntensity = attachedMesh.material.GetFloat("_EmissiveControl");
            mpb = new MaterialPropertyBlock();
        }
    }

    // Update is called once per frame
    void Update()
    {
        //Fractional Brown Motion
        float total = 0.0f;
        float frequency = initialFrequency;
        float amplitude = initialAmplitude;

        for (int i = 0; i < octaves; ++i)
        {
            total += Mathf.Sin(frequency * Time.time) * amplitude;
            amplitude *= gain;
            frequency *= lacunarity;
        }
        total /= (float)octaves;

        //Depending on threshold settings, either turns the light on or off
        if (total > threshold)
        {
            if (attachedLight) { attachedLight.intensity = (invertThresholdCondition) ? initialLightIntensity : 0.0f; }
            if (attachedMesh)
            {
                attachedMesh.GetPropertyBlock(mpb);
                mpb.SetFloat("_EmissiveControl", (invertThresholdCondition) ? initialEmissiveIntensity : 0.0f);
                attachedMesh.SetPropertyBlock(mpb);
            }
        }
        else
        {
            if (attachedLight) { attachedLight.intensity = (invertThresholdCondition) ? 0.0f : initialLightIntensity; }
            if (attachedMesh)
            {
                attachedMesh.GetPropertyBlock(mpb);
                mpb.SetFloat("_EmissiveControl", (invertThresholdCondition) ? 0.0f : initialEmissiveIntensity);
                attachedMesh.SetPropertyBlock(mpb);
            }
        }
    }
}
