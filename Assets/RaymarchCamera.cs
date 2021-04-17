﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : SceneViewFilter {
    [SerializeField] private Shader shader;
    [SerializeField] private float maxDistance;
    [SerializeField] private Color mainColor;
    [SerializeField] private Vector4 sphere1;
    [SerializeField] private Vector4 box1;
    [SerializeField] private Vector3 modInterval;
    [SerializeField] private Transform directionLight;

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
        RaymarchMat.SetColor("_MainColor", mainColor);
        RaymarchMat.SetVector("_Sphere1", sphere1);
        RaymarchMat.SetVector("_Box1", box1);
        RaymarchMat.SetVector("_ModInterval", modInterval);
        RaymarchMat.SetVector("_LightDir", directionLight ? directionLight.forward : Vector3.down);

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
