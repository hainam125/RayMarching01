using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : SceneViewFilter {
    [SerializeField] private Shader shader;

    [Header("Setup")]
    [SerializeField] private float maxDistance;
    [SerializeField] [Range(1, 300)] private int maxIteration;
    [SerializeField] [Range(0.1f, 0.001f)] private float accuracy;

    [Header("Signed Distance Field")]
    [SerializeField] private Color mainColor;
    [SerializeField] private Vector4 sphere1, sphere2;
    [SerializeField] private Vector4 box1;
    [SerializeField] private float box1Round;
    [SerializeField] private float boxSphereSmooth;
    [SerializeField] private float sphereIntersectSmooth;

    [Header("Directional Light")]
    [SerializeField] private Transform directionLight;
    [SerializeField] private Color lightColor;
    [SerializeField] private float lightIntensity;

    [Header("Shadow")]
    [SerializeField] private Vector2 shadowDistance;
    [SerializeField] [Range(0, 4)] private float shadowIntensity;
    [SerializeField] [Range(1, 128)] private float shadowPenumbra;

    [Header("Amibient Occulusion")]
    [SerializeField] [Range(0.01f, 10.0f)] private float aoStepSize;
    [SerializeField] [Range(1, 5)] private int aoIteration;
    [SerializeField] [Range(0f, 1f)] private float aoIntensity;

    private Material raymarchMat;
    private Material RaymarchMat {
        get {
            if (!raymarchMat && shader) {
                raymarchMat = new Material(shader);
                raymarchMat.hideFlags = HideFlags.HideAndDontSave;
            }
            return raymarchMat;
        }
    }

    private new Camera camera;
    private Camera Camera {
        get {
            if (!camera) camera = GetComponent<Camera>();
            return camera;
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination) {
        if (!RaymarchMat) {
            Graphics.Blit(source, destination);
            return;
        }

        RaymarchMat.SetMatrix("_CamFrustum", CamFrustum(Camera));
        RaymarchMat.SetMatrix("_CamToWorld", Camera.cameraToWorldMatrix);

        RaymarchMat.SetFloat("_MaxDistance", maxDistance);
        RaymarchMat.SetInt("_MaxIteration", maxIteration);
        RaymarchMat.SetFloat("_Accuracy", accuracy);

        RaymarchMat.SetColor("_MainColor", mainColor);
        RaymarchMat.SetVector("_Sphere1", sphere1);
        RaymarchMat.SetVector("_Sphere2", sphere2);
        RaymarchMat.SetVector("_Box1", box1);
        RaymarchMat.SetFloat("_Box1Round", box1Round);
        RaymarchMat.SetFloat("_BoxSphereSmooth", boxSphereSmooth);
        RaymarchMat.SetFloat("_SphereIntersectSmooth", sphereIntersectSmooth);

        RaymarchMat.SetVector("_LightDir", directionLight ? directionLight.forward : Vector3.down);
        RaymarchMat.SetColor("_LightCol", lightColor);
        RaymarchMat.SetFloat("_LightIntensity", lightIntensity);
        RaymarchMat.SetVector("_ShadowDistance", shadowDistance);
        RaymarchMat.SetFloat("_ShadowIntensity", shadowIntensity);
        RaymarchMat.SetFloat("_ShadowPenumbra", shadowPenumbra);

        RaymarchMat.SetFloat("_AoStepSize", aoStepSize);
        RaymarchMat.SetFloat("_AoIteration", aoIteration);
        RaymarchMat.SetFloat("_AoIntensity", aoIntensity);

        RenderTexture.active = destination;
        raymarchMat.SetTexture("_MainTex", source);
        GL.PushMatrix();
        GL.LoadOrtho();
        RaymarchMat.SetPass(0);
        GL.Begin(GL.QUADS);

        //bottom left
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        //bottom right
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //top right
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //top left
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }

    private Matrix4x4 CamFrustum(Camera cam) {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 topLeft = (-Vector3.forward - goRight + goUp);
        Vector3 topRight = (-Vector3.forward + goRight + goUp);
        Vector3 bottomRight = (-Vector3.forward + goRight - goUp);
        Vector3 bottomLeft = (-Vector3.forward - goRight - goUp);

        frustum.SetRow(0, topLeft);
        frustum.SetRow(1, topRight);
        frustum.SetRow(2, bottomRight);
        frustum.SetRow(3, bottomLeft);

        return frustum;
    }
}
