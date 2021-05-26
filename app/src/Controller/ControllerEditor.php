<?php

namespace Camagru\Controller;

require 'vendor/autoload.php';

use Camagru\Model\Repositories\LayerRepository;
use Camagru\Model\Repositories\ImageRepository;
use Camagru\Model\Entities\Image;
use Camagru\Service\ViewGenerator;
use \Exception;
use Aws\S3\S3Client;
use Aws\Exception\AwsException;
use Aws\S3\ObjectUploader;
use Aws\Credentials\CredentialProvider;

class ControllerEditor
{
    private $_viewGenerator;
    private $_imageRepository;
    private $_layerRepository;
    private $json;

    public function __construct($url)
    {
        if (isset($url) && count($url) > 1) {
            throw new Exception('Page Introuvable');
        } elseif (!isset($_SESSION['logged'])) {
            throw new Exception('Section Autorisée aux utilisateurs connectés');
        } elseif ($this->json = file_get_contents('php://input')) {
            $this->actionDispatch();
        } else {
            $this->editor();
        }
    }

    private function actionDispatch()
    {
        $this->json = json_decode($this->json, true);

        if (isset($this->json['img'])) {
            $this->createImg();
        } elseif (isset($this->json['save'])) {
            $this->saveImg();
        } else {
            $this->getLayers();
        }
    }

    private function editor()
    {
        $this->_layerRepository = new LayerRepository;
        $this->_viewGenerator = new ViewGenerator('Editor');
        $this->_viewGenerator->generate(array('layers' => $this->_layerRepository->getLayers()));
    }

    private function getLayers()
    {
        $this->_layerRepository = new LayerRepository;
        $layers = $this->_layerRepository->getLayers();
        $layers = $this->_layerRepository->getExposedLayers($layers);

        header('Content-Type: application/json');
        echo \json_encode($layers);
    }

    private function createImg()
    {
        $imgUrl = base64_decode(explode(',', $this->json['img'])[1]);
        $userImage = \imagecreatefromstring($imgUrl);

        $layerRepository = new LayerRepository;
        $layer = ($layerRepository->getLayerById($this->json['layer']))[0];
        $layerPath = $layer->pathToLayer();
        $layerImage = \imagecreatefrompng($_SERVER['DOCUMENT_ROOT'].$layerPath);
        $layerWidth = imagesx($layerImage);
        $layerHeight = imagesy($layerImage);
        
        $resizedLayer = imagecreatetruecolor($this->json['width'], $this->json['height']);
        
        imagealphablending($userImage, true);
        \imagesavealpha($userImage, true);
        
        imagealphablending($resizedLayer, false);
        \imagesavealpha($resizedLayer, true);
        
        imagecopyresampled($resizedLayer, $layerImage, 0, 0, 0, 0, $this->json['width'], $this->json['height'], $layerWidth, $layerHeight);
        imagecopyresampled($userImage, $resizedLayer, 240 - $this->json['width'] / 2, 135 - $this->json['height'] / 2, 0, 0, $this->json['width'], $this->json['height'], $this->json['width'], $this->json['height']);

        ob_start();
        imagepng($userImage);
        $contents =  ob_get_clean();

        header('Content-Type: application/json');
        echo json_encode(array('img' => \base64_encode($contents)));
    }
    
    private function saveImg()
    {
        $bucket = 'cloud1-bucket';
        $this->_imageRepository = new ImageRepository;
        $provider = CredentialProvider::defaultProvider();
        $creds = $provider()->wait();

        $imgUrl = $this->json['save'];
        $imgUrl = base64_decode($imgUrl);

        $imgId = (int)current($this->_imageRepository->getBiggestId()) + 1;
        $imgName = 'image_' . $imgId . '.jpg';
        $imgPathAWS = 'https://cloud1-bucket.s3.eu-west-3.amazonaws.com/'.$imgName;
        $imgPathFs = '/userImages/'.$imgName;
        $img = new Image(array('pathToImage' => $imgPathAWS, 'userId' => $_SESSION['logged']));
        $this->_imageRepository->add($img);
        file_put_contents($_SERVER['DOCUMENT_ROOT'] . $imgPathFs, $imgUrl);
        try {
            $s3Client = new S3Client([
                'region' => 'eu-west-3',
                'version' => 'latest',
                'credentials' => $creds,
            ]);
            $result = $s3Client->putObject([
                'Bucket' => $bucket,
                'Key' => $imgName,
                'SourceFile' => $_SERVER['DOCUMENT_ROOT'] . $imgPathFs,
                'ACL'    => 'public-read',
            ]);
        } catch (S3Exception $e) {
            echo $e->getMessage() . "\n";
        }
        \http_response_code(200);
    }
}
