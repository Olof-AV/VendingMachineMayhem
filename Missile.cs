using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public sealed class Missile : MonoBehaviour
{
    //Main settings, overriden by missile launcher's own parameters
    private LayerMask layersToHit = -1;
    private float missileDamage = 30.0f;
    private float missileSpeed = 20.0f;
    private float missileTurnSpeed = 5.0f;
    private float missileLifetime = 5.0f;

    //Internal functionning
    private GameObject targetToTrack = null;
    private Vector3 currentDir = Vector3.zero;

    //Used when making the component pool
    public void Setup(LayerMask _layers, float _damage, float _speed, float _turnSpeed, float _lifeTime)
    {
        layersToHit = _layers;
        missileDamage = _damage;
        missileSpeed = _speed;
        missileTurnSpeed = _turnSpeed;
        missileLifetime = _lifeTime;
    }

    //When spawning this missile, set up some final parameters
    public void Spawn(GameObject _targetToTrack, Vector3 _position, Vector3 _direction)
    {
        targetToTrack = _targetToTrack;
        transform.position = _position;
        currentDir = _direction;
        transform.rotation = Quaternion.LookRotation(currentDir);

        Invoke("Disable", missileLifetime);
    }

    //The main update logic
    private void Update()
    {
        //If there is a target to track, slightly re-orient to that target
        if(targetToTrack)
        {
            Vector3 expectedDir = (targetToTrack.transform.position - transform.position).normalized;
            currentDir = Vector3.Slerp(currentDir, expectedDir, missileTurnSpeed * Time.deltaTime).normalized;
        }

        //Update rotation
        transform.rotation = Quaternion.LookRotation(currentDir);

        //Move
        transform.position += currentDir * missileSpeed * Time.deltaTime;
    }

    //On collision
    private void OnTriggerEnter(Collider other)
    {
        //Don't respond to triggers
        if(!other.isTrigger)
        {
            if(other.gameObject.IsInLayerMasks(layersToHit))
            {
                //If there is a health component, damage
                Health health = other.GetComponentInParent<Health>();
                health?.TakeDamage(missileDamage);

                //Disable instead of deleting
                Disable();
            }
        }
    }

    //Turn off projectile
    private void Disable()
    {
        //Always disable instead of deleting object
        gameObject.SetActive(false);
        CancelInvoke();
    }
}
