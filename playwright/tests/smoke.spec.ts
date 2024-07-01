import {test} from '@playwright/test';

test('smokeTest', async ({page}) => {
	const url = 'localhost:' + process.env.CONTAINER_EXPORTED_PORT;

	await page.goto(url);

	await page.getByRole('button', {name: 'Sign In'}).click();

	await page.getByLabel('Email Address').click();

	await page.getByLabel('Email Address').fill('test@liferay.com');

	await page.getByLabel('Email Address').press('Tab');

	await page.getByLabel('Password').fill('test');

	await page.getByLabel('Password').press('Tab');

	await page.getByLabel('Remember Me').press('Tab');

	await page
		.getByLabel('Sign In- Loading')
		.getByRole('button', {name: 'Sign In'})
		.press('Enter');

	await page.getByRole('button', {name: 'Save'}).waitFor({state: 'visible'});

	await page.getByLabel('Password', {exact: true}).click();

	await page.getByLabel('Password', {exact: true}).fill('password');

	await page.getByLabel('Password', {exact: true}).press('Tab');

	await page.getByLabel('Reenter Password').fill('password');

	await page.getByLabel('Reenter Password').press('Tab');

	await page.getByRole('button', {name: 'Save'}).press('Enter');

	const responsePromise = page.waitForResponse(
		'**/o/com-liferay-enterprise-product-notification-web/confirm/'
	);

	await page.getByRole('button', {name: 'Done'}).click();

	await responsePromise;

	await page.getByLabel('Test Test User Profile').click();

	await page.getByRole('menuitem', {name: 'Account Settings'}).click();

	await page.getByRole('link', {name: 'Password'}).click();

	await page.getByLabel('Current Password Required').click();

	await page.getByLabel('Current Password Required').fill('password');

	await page.getByLabel('New Password Required').click();

	await page.getByLabel('New Password Required').fill('new-password');

	await page.getByLabel('Reenter Password Required').click();

	await page.getByLabel('Reenter Password Required').fill('new-password');

	await page.getByRole('button', {name: 'Save'}).click();
});