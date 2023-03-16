using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaterSimulation : MonoBehaviour
{
    [SerializeField] private CustomRenderTexture heightMap; // 波動シュミレーションの出力ハイトマップ
    [SerializeField] private int count = 5;                 // 1フレームにつきcount回更新
    private CustomRenderTextureUpdateZone defaultZone;      // "Update"Passのテクスチャ設定

    private void Start()
    {
        heightMap.Initialize(); // ハイトマップの初期化
        SetDefaultZone();       // "Update"Passのテクスチャを設定
    }

    private void Update()
    {
        heightMap.ClearUpdateZones(); // "Update"Passに設定
        UpdateZones();                // Passの更新
        heightMap.Update(count);      // ハイトマップの更新
    }

    private void SetDefaultZone()
    {
        defaultZone = new CustomRenderTextureUpdateZone()
        {
            needSwap = true,                          // ダブルバッファの更新を要求
            passIndex = 0,                            // "Update"Passのインデックス
            rotation = 0,                             // テクスチャの回転
            updateZoneCenter = new Vector2(.5f, .5f), // テクスチャの中心
            updateZoneSize = new Vector2(1, 1),       // テクスチャのサイズ
        };
    }

    private void UpdateZones()
    {
        bool leftClick = Input.GetMouseButton(0);
        bool rightClick = Input.GetMouseButton(1);

        if (!leftClick && !rightClick)
        {
            return;
        }

        RaycastHit hitInfo;
        var ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        if (Physics.Raycast(ray, out hitInfo))
        {
            // "Click"Passのテクスチャ設定
            var clickZone = new CustomRenderTextureUpdateZone()
            {
                needSwap = true,                                                                    // ダブルバッファの更新を要求
                passIndex = leftClick ? 1 : 2,                                                      // "Click"Passのインデックス
                rotation = 0,                                                                       // テクスチャの回転
                updateZoneCenter = new Vector2(hitInfo.textureCoord.x, 1 - hitInfo.textureCoord.y), // テクスチャの中心
                updateZoneSize = new Vector2(.01f, .01f),                                         // テクスチャのサイズ
            };
            

            // ハイトマップ全体の更新
            heightMap.SetUpdateZones(new CustomRenderTextureUpdateZone[] { defaultZone, clickZone });
        }
    }
}
