# Push the executor to Action

Push the executor to hub with the tags `$git_tag` and `latest`

One need to specify the input `git_tag` and set the following secrets in the repo

- `nextlinuxhub_token`: token of your NextLinux AI Cloud account

You need to pass this to the action like so:

```yml
      - name: action to push
        uses: nextlinux/action-push-hub@v3
        env: 
          jinahub_token: ${{ secrets.nextlinuxhub_token }}
```

If you want to release the GPU version, make sure you have `Dockerfile.gpu` in your root folder

Note that the old `exec_secret` is deprecated and removed from this action.
