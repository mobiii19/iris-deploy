# Iris Prediction API — CE408L Week 8

A small Flask API that serves predictions from a scikit-learn model stored in
Amazon S3. It is the application payload for **Week 8: Cloud Application
Deployment (EC2 + Flask + S3)**.

The machine learning here is deliberately trivial. The lab is about
**deployment and IAM**: where the model artifact lives, which identity is
allowed to read it, and how an EC2 instance provisions itself at boot.

```
client  ->  Flask API on EC2  ->  model downloaded from S3 at startup
```

## Files

| File | Purpose | Runs where |
|---|---|---|
| `train_model.py` | Trains a Random Forest on the Iris dataset, saves `iris_model.pkl` | Your laptop |
| `upload_model.py` | Uploads the model to your S3 bucket | Your laptop |
| `app.py` | Flask API: `/health` and `/predict` | Laptop, then EC2 |
| `requirements.txt` | Pinned dependencies | Both |
| `user-data-template.sh` | EC2 boot script — paste into Advanced details, do not commit your edited copy | EC2 launch wizard |
| `.gitignore` | Keeps the model, the venv and any keys out of git | — |

## Quick start (local)

```bash
python3 -m venv venv
source venv/bin/activate          # Windows: .\venv\Scripts\Activate.ps1
pip install -r requirements.txt

python train_model.py             # prints test accuracy, writes iris_model.pkl
```

Create an S3 bucket, put its name at the top of `upload_model.py`, then:

```bash
python upload_model.py
```

Run the API locally (uses your own AWS credentials):

```bash
export MODEL_BUCKET=ml-iris-model-<yourname>    # PowerShell: $env:MODEL_BUCKET="..."
python app.py
```

In a second terminal:

```bash
curl http://localhost:5000/health

curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{"features":[5.1,3.5,1.4,0.2]}'
```

Expected: `{"class_name":"setosa","features":[5.1,3.5,1.4,0.2],"prediction":0}`

Try `[6.7,3.0,5.2,2.3]` for a different class (virginica).

## Deploying to EC2

1. Create an IAM role for EC2 with an **inline** policy — not the managed
   `AmazonS3ReadOnlyAccess`, which grants read access to every bucket you own:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Sid": "ReadOneModelBucketOnly",
       "Effect": "Allow",
       "Action": "s3:GetObject",
       "Resource": "arn:aws:s3:::ml-iris-model-<yourname>/*"
     }]
   }
   ```

   The `/*` suffix is required: `s3:GetObject` acts on objects inside the
   bucket, not on the bucket itself.

2. Launch an Ubuntu 22.04 instance, attach that role, open port 22 and port
   5000 to your IP, and paste your edited `user-data-template.sh` into
   **Advanced details → User data**.

3. Wait 4–5 minutes after the status checks pass, then:

   ```bash
   curl http://<public-ip>:5000/health
   ```

## API

### `GET /health`

`200` when the model loaded, `503` when it did not — the error is included so
you can tell an IAM problem from a missing object.

```json
{"status": "healthy", "model_loaded": true, "instance_id": "i-0abc123"}
```

### `POST /predict`

Body: `{"features": [sepal_length, sepal_width, petal_length, petal_width]}`

```json
{"prediction": 0, "class_name": "setosa", "features": [5.1, 3.5, 1.4, 0.2]}
```

Returns `400` for malformed input and `503` if the model is not loaded.

## Notes

- **No AWS credentials appear anywhere in this repository.** On EC2, boto3
  reads temporary credentials from the instance role automatically. Locally it
  uses whatever `aws configure` set up.
- **The model is never committed.** It lives in S3, which is the source of
  truth; `.gitignore` excludes `*.pkl`.
- **Dependency versions are pinned** so the model trained on your laptop loads
  on the instance without a scikit-learn version mismatch.
- The repository must be **public** for the User Data script to clone it
  without credentials.
